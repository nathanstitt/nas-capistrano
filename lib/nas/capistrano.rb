require "nas/capistrano/version"

module NAS

    module Capistrano

        def last_release_time
            @last_release_time ||= capture( "ls -l --full-time #{releases_path} | tail -2 | head -1 | awk '{print $6, $7}'" )
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
            with fetch(:git_environmental_variables) do
                capture(:git,"--bare",:log,"--format=oneline","--after='#{last_release_time}'",
                    "-- #{paths.join(' ')}","|wc -l").to_i
            end
        end

    end

end

include NAS::Capistrano
