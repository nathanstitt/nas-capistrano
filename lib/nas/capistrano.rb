require "nas/capistrano/version"

module NAS

    module Capistrano

        def last_release
            @last_release ||= capture(:ls, releases_path, '| tail -1')
        end

        def dry_run?
            fetch(:sshkit_backend) == SSHKit::Backend::Printer
        end

        def run_locally(cmd)
            if dry_run?
                info "executing locally: #{cmd.inspect}"
                return ''
            end
            output_on_stdout = `#{cmd}`
            if $?.to_i > 0 # $? is command exit code (posix style)
                fail "Command #{cmd} returned status code #{$?}\n#{output_on_stdout}"
            end
            output_on_stdout
        end

        def change_count_for_paths( *paths )
            last = last_release.gsub(/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})*/,'\1-\2-\3 \4:\5')
            capture( "cd #{repo_path} git shortlog -s --after='#{last}' -- #{paths.join(' ')}| awk '{ sum+=$1} END {print sum}'" ).to_i
        end

    end

end

include NAS::Capistrano
