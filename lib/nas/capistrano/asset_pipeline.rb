require 'nas/capistrano/common'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
Capistrano::Configuration.instance(:must_exist) :
    Capistrano.configuration(:must_exist)

configuration.load do


    after 'deploy:finalize_update', 'deploy:assets:update'
    before "deploy", "deploy:debugcheck"

    set :bundle_without,  [:development, :test, :assets]

    namespace :deploy do

        desc "test for console & debug in app/assets/javascripts"
        task :debugcheck do
            unless ( msg = `egrep -R -e"debugger|console\.[log|info|warn|error]" app/assets/javascripts/*|grep -v '[#|\/\/]'` ).empty?
                abort "console/debugger stmtleft in code:\n" + msg
            end
        end

        namespace :assets do

            desc "precompile assets"
            task :precompile do
                # NOOP to over-ride built in cap task
            end

            task :update do
                from = source.next_revision(current_revision)
                if ENV['FORCE_ASSETS'] || capture("cd #{latest_release} && #{source.local.log(from)} vendor/assets/ lib/assets/ app/assets/ | wc -l").to_i > 0
                    deploy.assets.upload
                else
                    logger.info "Skipping asset precompilation because there were no asset changes. FORCE_ASSETS=1 to force"
                end
            end

            task :upload, :roles => :web do
                run_locally("rake assets:clean && rake assets:precompile")
                run_locally "cd public && tar -jcf assets.tar.bz2 assets"
                top.upload "public/assets.tar.bz2", "#{shared_path}", :via => :scp
                run "find #{shared_path}/assets -type f -mtime +30 -print0 | xargs -0 --no-run-if-empty rm"
                run "cd #{shared_path} && tar -jxf assets.tar.bz2 && rm assets.tar.bz2"
                run_locally "rm public/assets.tar.bz2"
                run_locally("rake assets:clean")
            end
        end

    end

end
