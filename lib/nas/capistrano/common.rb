
require 'bundler/capistrano'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
Capistrano::Configuration.instance(:must_exist) :
    Capistrano.configuration(:must_exist)

configuration.load do

    _cset :user, "nas"
    _cset :use_sudo, false

    _cset :scm, :git
    _cset :branch, 'master'


    server = Capistrano::Configuration.instance.variables[:server]
    set :domain, server
    role :web,   server
    role :app,   server
    role :db,    server, :primary=>true

    _cset(:appdir) { "/srv/www/#{application}" }
    set(:deploy_to)       { appdir }

    _cset :normalize_asset_timestamps, false

    set :repository,  "ssh://nas@#{server}/srv/git/#{application}.git"

    ssh_options[:forward_agent]

    if !ENV["NO_PUSH"]
        before "deploy", "deploy:push"
        before "deploy:migrations", "deploy:push"
    end

    after 'deploy:finalize_update', 'deploy:make_symlinks'

    after "deploy:restart", "deploy:cleanup"

    namespace :remote do

        desc 'run rake task'
        task :rake do
            run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec rake #{rake_task}"
        end
    end

    namespace :deploy do

        task :start do ; end
        task :stop do ; end
        # Assumes you are using Passenger
        task :restart, :roles => :app, :except => { :no_release => true } do
            run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
        end

        desc "Symlink in files/directories that are shared between releases"
        task :make_symlinks, :roles => :app do
            run "ln -nfs #{deploy_to}/shared/config/database.yml #{release_path}/config/database.yml"
            run "ln -nfs #{deploy_to}/shared/assets #{release_path}/public/assets"
        end

        desc "Push local changes to Git repository"
        task :push do
            status = %x(git status --porcelain).chomp
            if status != ""
                if status !~ %r{^[M ][M ] config/deploy.rb$}
                    raise Capistrano::Error, "Local git repository has uncommitted changes"
                elsif !ENV["IGNORE_DEPLOY_RB"]
                    # This is used for testing changes to this script without committing them first
                    raise Capistrano::Error, "Local git repository has uncommitted changes (set IGNORE_DEPLOY_RB=1 to ignore changes to deploy.rb)"
                end
            end
            # Check we are on the master branch, so we can't forget to merge before deploying
            branch = %x(git branch --no-color 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \\(.*\\)/\\1/').chomp
            if branch != "master" && !ENV["IGNORE_BRANCH"]
                raise Capistrano::Error, "Not on master branch (set IGNORE_BRANCH=1 to ignore)"
            end
            # Push the changes
            if ! system "git push #{fetch(:repository)} master"
                raise Capistrano::Error, "Failed to push changes to #{fetch(:repository)}"
            end
        end

    end

    desc "tail production log files"
    task :logtail, :roles => :app do
        trap("INT") { puts 'Interupted'; exit 0; }
        run "tail -n200 -f #{shared_path}/log/production.log" do |channel, stream, data|
            puts  # for an extra line break before the host name
            puts "#{channel[:host]}: #{data}"
            break if stream == :err
        end
    end

end
