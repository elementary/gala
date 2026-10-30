mutter_tests_datadir = libmutter_test_dep.get_variable('tests_datadir')
dbusrunnerconf = configuration_data()
dbusrunnerconf.set('MUTTER_TEST_PKGDATADIR', mutter_tests_datadir)

dbus_runner = configure_file(
    input: 'gala_dbus_runner.py.in',
    output: 'gala_dbus_runner.py',
    configuration: dbusrunnerconf,
)

common_test_sources = files(
    'MutterTestCase.vala',
    'TestCase.vala',
    'TestRunner.vala',
)

subdir('lib')
