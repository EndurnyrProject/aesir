defmodule Aesir.Commons.GameModeTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Commons.GameMode

  setup :set_mimic_private
  setup :verify_on_exit!

  test "resolves renewal in the test environment" do
    assert GameMode.mode() == :renewal
  end

  test "reads the configured mode when it has not been cached" do
    expect(Application, :get_env, fn :commons, :game_mode, :renewal -> :pre_renewal end)

    assert GameMode.mode() == :pre_renewal
  end

  test "converts modes to protocol enum values" do
    assert GameMode.proto_enum(:renewal) == :GAME_MODE_RENEWAL
    assert GameMode.proto_enum(:pre_renewal) == :GAME_MODE_PRE_RENEWAL
  end
end
