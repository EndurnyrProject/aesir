defmodule Aesir.ZoneServer.IntegrationModeSelectionFixture do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.GameMode

  test "shared integration" do
    IO.puts("\nselection:shared")
  end

  describe "renewal integrations" do
    @describetag game_mode: :renewal, integration_pre_re: false

    test "renewal integration" do
      assert GameMode.mode() == :renewal
      IO.puts("\nselection:renewal")
    end
  end

  describe "pre-renewal integrations" do
    @describetag game_mode: :pre_renewal, integration_re: false

    test "pre-renewal integration" do
      assert GameMode.mode() == :pre_renewal
      IO.puts("\nselection:pre_renewal")
    end
  end
end
