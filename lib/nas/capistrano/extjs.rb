require 'nas/capistrano/common'

before "deploy:starting",  "nas:extjs:debugcheck"
before "deploy:updated",   "nas:extjs:upload"
after  "deploy:symlink:release", "nas:extjs:link"

namespace :nas do

    namespace :extjs do

        desc "test for console & debug in public/app"
        task :debugcheck do
            unless ( msg = `egrep -R -e"debugger|console\.[log|info|warn|error]" public/app/*|grep -v "#"` ).empty?
                abort "console/debugger stmt left in code:\n" + msg
            end
        end

        desc "build extjs classes"
        task :build do
            on roles(:web) do | host |
                output = run_locally("rake build:coffee")
                Dir.chdir( 'public' ) do
                    start = Time.now
                    info "Starting ExtJS compilation"
                    pid = Kernel.fork do
                        %w{GEM_HOME GEM_PATH RUBYOPT}.each{ |var| ENV.delete(var) }
                        output = `source $(rvm 1.9 do rvm env --path) && sencha app build`
                        if output =~ /BUILD FAILED/ || 0 != $?.exitstatus
                            fail "Sencha compile failed:\n#{output}"
                        end
                    end
                    Process.waitpid(pid)
                    fail "ExtJS Build failure" if 0 != $?.exitstatus
                    info "Finished ExtJS compilation (#{(Time.now-start).round(2)} seconds)"
                end
            end
        end

        desc "upload extjs compiled & minimized source"
        task :upload do
            on roles(:web) do | host |
                unless ENV['FORCE_EXTJS'] || change_count_for_paths( 'public/app' ) > 0
                    info "Skipping ExtJS compilation because there were no changes in public/app. FORCE_EXTJS=1 to force"
                    next
                end
                invoke 'extjs:build'

                src  = './public/build/production/App'
                dest = "#{deploy_to}/shared/extjs"
                [ "#{src}/resources/App-all.css", "#{src}/app.js" ].each do | file |
                    ext = File.extname(file)
                    run_locally "gzip -f #{file}"
                    upload! "#{file}.gz", "#{dest}/app#{ext}.gz"
                    execute "gunzip -c #{dest}/app#{ext}.gz > #{dest}/app#{ext}"
                end
                info `rsync -aqz -e ssh \"#{src}/resources/images\" \"#{host.user}@#{host.hostname}:#{dest}/\"`
            end
        end

        desc "Link shared extjs directory into public"
        task :link do
            on roles(:web) do
                pub = "#{release_path}/public"
                execute "rm -r #{pub}/build* #{pub}/app/* #{pub}/ext #{pub}/bootstrap.js"
                execute "ln -nfs #{deploy_to}/shared/extjs #{pub}/ext"
            end
        end

    end

end
