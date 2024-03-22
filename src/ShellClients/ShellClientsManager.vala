public class Gala.ShellClientsManager : Object {
    public Meta.Display display { get; construct; }

    private NotificationsClient notifications_client;

    public ShellClientsManager (Meta.Display display) {
        Object (display: display);
    }

    construct {
        notifications_client = new NotificationsClient (display);
    }
}
