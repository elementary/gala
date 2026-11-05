mutter_tests_datadir = libmutter_test_dep.get_variable('tests_datadir')

if not fs.exists(mutter_tests_datadir / 'mutter_dbusrunner.py')
    error(
        'mutter_dbusrunner.py does not exist in the expected location.' +
        'On ubuntu you may need to install mutter-(api version)-tests'
    )
endif

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
