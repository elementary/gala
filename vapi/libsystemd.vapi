[CCode (cheader_filename = "systemd/sd-daemon.h")]
namespace Systemd.Daemon {
    [CCode (cname="sd_notify")]
    int notify([CCode (type="int")]bool unset_environment, string state);

    [CCode (cname="sd_notifyf")]
    int notifyf([CCode (type="int")]bool unset_environment, string format, ...);

    [CCode (cname="sd_pid_notify")]
    int pid_notify(Posix.pid_t pid, [CCode (type="int")]bool unset_environment, string state);

    [CCode (cname="sd_pid_notifyf")]
    int pid_notifyf(Posix.pid_t pid, [CCode (type="int")]bool unset_environment, string format, ...);

    [CCode (cname="sd_pid_notify_with_fds")]
    int pid_notify_with_fds(Posix.pid_t pid, [CCode (type="int")]bool unset_environment, string state, int[] fds);
}

