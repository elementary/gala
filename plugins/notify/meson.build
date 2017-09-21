notify_files = [
    'ConfirmationNotification.vala',
    'Main.vala',
    'NotifySettings.vala',
    'NotifyServer.vala',
    'NotificationStack.vala',
    'Notification.vala',
    'NormalNotification.vala'
]

shared_module('gala-notify', notify_files,
              dependencies: [core_dependencies, gala_dependencies, notification_dependencies],
              include_directories: libgala_dir,
              install: true,
              install_dir: plugin_dir)

install_data('data/image-mask.svg',
    install_dir: pkg_data_dir)
