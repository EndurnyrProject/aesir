defmodule Aesir.ZoneServer.Guild.EmblemValidatorTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Guild.EmblemValidator

  defp bmp(width, height, padding \\ 0) do
    "BM" <>
      <<0::size(16 * 8)>> <>
      <<width::little-signed-32, height::little-signed-32>> <> <<0::size(padding * 8)>>
  end

  describe "validate/1" do
    test "accepts a 24x24 BMP" do
      assert EmblemValidator.validate(bmp(24, 24)) == :ok
    end

    test "rejects a blob without the BM magic" do
      not_bmp = "ZZ" <> <<0::size(24 * 8)>>

      assert EmblemValidator.validate(not_bmp) == {:error, :invalid_emblem}
    end

    test "rejects a 32x32 BMP" do
      assert EmblemValidator.validate(bmp(32, 32)) == {:error, :invalid_emblem}
    end

    test "rejects a BMP larger than 100 KB" do
      oversized = bmp(24, 24, 102_400)

      assert byte_size(oversized) > 102_400
      assert EmblemValidator.validate(oversized) == {:error, :invalid_emblem}
    end

    test "rejects a truncated header" do
      assert EmblemValidator.validate("BM") == {:error, :invalid_emblem}
    end
  end
end
