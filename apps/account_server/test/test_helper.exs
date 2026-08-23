# Copy the mocked modules once, before any test runs. Calling `Mimic.copy/1`
# from inside a test reloads a module that other umbrella apps already copied
# in this VM, which makes the code server report
# "Module ... must be purged before deleting" mid-run.
Mimic.copy(Aesir.Commons.Auth)
Mimic.copy(Aesir.Commons.SessionManager)

ExUnit.start()
