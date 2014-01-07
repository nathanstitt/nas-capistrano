require 'nas/capistrano/common'

before "deploy:starting", "nas:assets:debugcheck"
after  "deploy:updated",  "nas:assets:check"

set :bundle_without,  [:development, :test, :assets]


namespace :nas do

    namespace :assets do

        desc "test for console & debug in app/assets/javascripts"
        task :debugcheck do
            on roles(:all) do
                unless ( msg = `egrep -R -e"debugger|console\.[log|info|warn|error]" app/assets/javascripts/*|grep -v '[#|\/\/]'` ).empty?
                    abort "console/debugger stmtleft in code:\n" + msg
                end
            end
        end

        desc "precompile assets"
        task :precompile do
            # NOOP to over-ride built in cap task
        end

        task :check do
            on roles(:web) do
                if ENV['FORCE_ASSETS'].nil? && change_count_for_paths( 'app/assets' ).zero?
                    info "Skipping asset precompilation because there were no asset changes. FORCE_ASSETS=1 to force"
                else
                    Rake::Task["nas:assets:update"].invoke
                end
            end
        end

        task :update do
            on roles(:web) do
                FileUtils.rm_rf("public/assets")
                run_locally("rake assets:clean && rake assets:precompile")
                run_locally "cd public && tar -jcf assets.tar.bz2 assets"
                upload! "public/assets.tar.bz2", "#{shared_path}"
                execute "find #{shared_path}/assets -type f -mtime +30 -print0 | xargs -0 --no-run-if-empty rm"
                execute "find #{shared_path}/assets -type f -name 'manifest*' -exec rm {} \\;"
                execute "cd #{shared_path} && tar -jxf assets.tar.bz2 && rm assets.tar.bz2"
                run_locally "rm public/assets.tar.bz2"
                run_locally("rake assets:clean")
            end
        end

    end

end
