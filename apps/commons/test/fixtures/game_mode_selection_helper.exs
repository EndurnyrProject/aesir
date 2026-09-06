alias Aesir.Commons.GameMode
alias Aesir.GameModeTestSupport

runtime = Path.expand("../../../../config/runtime.exs", __DIR__)
Application.put_all_env(Config.Reader.read!(runtime))
GameMode.cache!()

if System.argv() != [] do
  ExUnit.start(autorun: false, exclude: [:test], include: ExUnit.Filters.parse(System.argv()))
end

GameModeTestSupport.start(
  autorun: false,
  exclude: [:distributed],
  assert_receive_timeout: 500
)

GameModeTestSupport.start(exclude: [:fixture_only])

defmodule Aesir.GameModeSelectionFixture do
  use ExUnit.Case

  test "shared" do
    assert ExUnit.configuration()[:assert_receive_timeout] == 500
    IO.puts("\nselection:shared")
  end

  @tag game_mode: :renewal
  test "renewal" do
    assert GameMode.mode() == :renewal
    IO.puts("\nselection:renewal")
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal" do
    assert GameMode.mode() == :pre_renewal
    IO.puts("\nselection:pre_renewal")
  end

  @tag :distributed
  test "preserves the first caller's exclusion" do
    flunk("distributed fixture must remain excluded")
  end

  @tag :fixture_only
  test "preserves the second caller's exclusion" do
    flunk("local fixture must remain excluded")
  end
end

defmodule Aesir.IntegrationSelectionFixture do
  use ExUnit.Case

  @moduletag integration_re: true, integration_pre_re: true

  test "shared integration" do
    IO.puts("\nselection:integration_shared")
  end

  describe "renewal integrations" do
    @describetag game_mode: :renewal, integration_pre_re: false

    test "describe tags disable the opposite integration family" do
      assert GameMode.mode() == :renewal
      IO.puts("\nselection:integration_renewal")
    end

    @tag game_mode: :pre_renewal, integration_re: false, integration_pre_re: true
    test "test tags override the inherited describe tags" do
      assert GameMode.mode() == :pre_renewal
      IO.puts("\nselection:integration_pre_renewal")
    end
  end
end

%{failures: failures} = ExUnit.run()
System.halt(if failures == 0, do: 0, else: 1)
