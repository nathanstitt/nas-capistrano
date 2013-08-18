require 'nas/capistrano/common'
require 'nas/capistrano/asset_pipeline'
require 'digest/md5'


configuration = Capistrano::Configuration.respond_to?(:instance) ?
Capistrano::Configuration.instance(:must_exist) :
    Capistrano.configuration(:must_exist)


configuration.load do

    after 'deploy:finalize_update', 'extjs:upload'
    before "deploy", "extjs:debugcheck"

    namespace :extjs do

        desc "test for console & debug in public/app"
        task :debugcheck do
            unless ( msg = `egrep -R -e"debugger|console\.[log|info|warn|error]" public/app/*|grep -v "#"` ).empty?
                abort "console/debugger stmt left in code:\n" + msg
            end
        end

        desc "build extjs classes"
        task :build do
            from = source.next_revision(current_revision)
            if ENV['FORCE_UPLOAD'] || capture("cd #{latest_release} && #{source.local.log(from)} public/app/ | wc -l").to_i > 0
                output = run_locally("rake build:coffee")
                Dir.chdir( 'public' ) do
                    start = Time.now
                    logger.info "Starting ExtJS compilation"
                    pid = Kernel.fork do
                        %w{GEM_HOME GEM_PATH RUBYOPT}.each{ |var| ENV.delete(var) }
                        output = `source $(rvm 1.9 do rvm env --path) && sencha app build`
                        if output =~ /BUILD FAILED/ || 0 != $?.exitstatus
                            raise Capistrano::Error, "Sencha compile failed:\n#{output}"
                        end
                    end
                    Process.waitpid(pid)
                    abort("ExtJS Build failure") if 0 != $?.exitstatus
                    logger.info "Finished ExtJS compilation (#{(Time.now-start).round(2)} seconds)"
                end
            else
                logger.info "Skipping ExtJS compilation because there were no changes in public/app. FORCE_EXT_UPLOAD=1 to force"
            end
        end

        before 'extjs:upload', 'extjs:build'
        desc "upload extjs compiled & minimized source"
        task :upload do
            server = configuration.variables[:server]
            dest = './public/build/App/production'
            `rsync -avz -e ssh \"#{dest}/\" \"#{user}@#{server}:#{shared_path}/extjs/\" --exclude '*.html'`
            pub = "#{release_path}/public"
            run "rm -r #{pub}/build* #{pub}/app/* #{pub}/ext #{pub}/bootstrap.js"
            file = "#{dest}/all-classes.js"
            md5 = Digest::MD5.hexdigest(File.read(file))
            dest = "#{shared_path}/assets/app-#{md5}.js"
            run "ln -nfs #{deploy_to}/shared/extjs/resources #{release_path}/public/resources"
            run "ln -nfs #{deploy_to}/shared/extjs/ext #{release_path}/public/ext"
            run "mv #{shared_path}/extjs/all-classes.js #{dest}"
            run "gzip -c #{dest} > #{dest}.gz"
            run "echo 'app.js: app-#{md5}.js' >> #{shared_path}/assets/manifest.yml"
        end
    end

end
