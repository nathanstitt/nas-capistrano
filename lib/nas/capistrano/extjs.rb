require 'nas/capistrano/common'
require 'nas/capistrano/asset_pipeline'
require 'digest/md5'


configuration = Capistrano::Configuration.respond_to?(:instance) ?
Capistrano::Configuration.instance(:must_exist) :
    Capistrano.configuration(:must_exist)


configuration.load do

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
        end


        before 'extjs:link', 'extjs:upload'
        desc "upload extjs compiled & minimized source"
        task :upload do
            from = source.next_revision(current_revision)
            unless ENV['FORCE_EXTJS'] || capture("cd #{latest_release} && #{source.local.log(from)} public/app/ | wc -l").to_i > 0
                logger.info "Skipping ExtJS compilation because there were no changes in public/app. FORCE_EXTJS=1 to force"
                next
            end
            extjs.build
            server = configuration.variables[:server]
            src  = './public/build/App/production'
            dest = "#{deploy_to}/shared/extjs"
            css = "#{src}/resources/App-all.css"
            js  = "#{src}/all-classes.js"
            output = `gzip -f #{css} && gzip -f #{js}`
            raise Capistrano::Error, "gzip ExtJS assets failed:\n#{output}" if 0 != $?.exitstatus
            top.upload "#{css}.gz", "#{dest}/app.css.gz", :via => :scp
            top.upload "#{js}.gz",  "#{dest}/app.js.gz",  :via => :scp
            %w{js css}.each{ |ext| run "gunzip -c #{dest}/app.#{ext}.gz > #{dest}/app.#{ext}" }
            `rsync -avz -e ssh \"#{src}/resources/images\" \"#{user}@#{server}:#{dest}/\"`
        end


        after 'deploy:finalize_update', 'extjs:link'
        desc "Link shared extjs directory into public"
        task :link do
            pub = "#{release_path}/public"
            run "rm -r #{pub}/build* #{pub}/app/* #{pub}/ext #{pub}/bootstrap.js"
            run "ln -nfs #{deploy_to}/shared/extjs #{pub}/ext"
        end
    end

end
