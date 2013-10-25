require "nas/capistrano"
require "capistrano/rails/migrations"

set :user, "nas"
set :use_sudo, false

set :scm, :git
set :branch, 'master'
set :keep_releases, 10

set :normalize_asset_timestamps, false

if !ENV["NO_PUSH"]
    before "deploy:starting", "nas:push"
end

after 'deploy:symlink:release', 'nas:make_symlinks'


require 'capistrano/all'
require 'capistrano/bundler'

before 'bundler:install', "bundler:setup"

namespace :bundler do
    task :setup do
        set :bundle_gemfile, -> { release_path.join('Gemfile') }
        set :bundle_dir, -> { shared_path.join('bundle') }
        set :bundle_flags, '--deployment --quiet'
        set :bundle_without, %w{development test assets}.join(' ')
        set :bundle_binstubs, -> { shared_path.join('bin') }
        set :bundle_roles, :all
    end

end

namespace :deploy do

    desc 'Restart application'
    task :restart do
        on roles(:app), in: :sequence, wait: 5 do
            execute :touch, release_path.join('tmp/restart.txt')
        end
    end

end

namespace :nas do

    desc "Symlink in files/directories that are shared between releases"
    task :make_symlinks do
        on roles(:app), in: :parallel do
            execute :ln, "-nfs", "#{deploy_to}/shared/config/database.yml", "#{release_path}/config/database.yml"
            execute :ln, "-nfs", "#{deploy_to}/shared/assets", "#{release_path}/public/assets"
        end
    end

    desc "Push local changes to Git repository"
    task :push do
        on roles(:app) do | host |
            status = %x(git status --porcelain).chomp
            unless status.empty? || ENV["UNCLEAN"]
                fail "Local git repository has uncommitted changes (set UNCLEAN=1 to ignore changes to deploy.rb)"
            end
            # Check we are on the master branch, so we can't forget to merge before deploying
            branch = %x(git branch --no-color 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \\(.*\\)/\\1/').chomp
            if branch != "master" && !ENV["IGNORE_BRANCH"]
                fail "Not on master branch (set IGNORE_BRANCH=1 to ignore)"
            end
            # Push the changes
            repo = "ssh://#{host.user}@#{host.hostname}/srv/git/#{fetch(:application)}.git master"
            run_locally( "git push #{repo}" )
        end
    end

end

desc "tail production log files"
task :logtail do
    on roles(:app) do
        trap("INT") { puts 'Interupted'; exit 0; }
        execute "tail -n200 -f #{shared_path}/log/production.log" do |channel, stream, data|
            puts  # for an extra line break before the host name
            puts "#{channel[:host]}: #{data}"
            break if stream == :err
        end
    end
end
