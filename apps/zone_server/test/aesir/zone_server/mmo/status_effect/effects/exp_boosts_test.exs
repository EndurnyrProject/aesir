defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ExpBoostsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEntry

  # {module, status id, modifier key, icon atom}
  @modules [
    {Effects.ExpBoost, :sc_expboost, :exp_rate, :cash_plusexp},
    {Effects.JexpBoost, :sc_jexpboost, :job_exp_rate, :cash_plusonlyjobexp}
  ]

  defp entry(type, val1), do: %StatusEntry{type: type, state: %{}, val1: val1}

  describe "modifiers/2" do
    for {module, type, key, _icon} <- @modules do
      test "#{inspect(module)} emits +val1 as #{key}" do
        assert %{unquote(key) => 50} ==
                 unquote(module).modifiers(entry(unquote(type), 50), %{})

        assert %{unquote(key) => 10} ==
                 unquote(module).modifiers(entry(unquote(type), 10), %{})
      end
    end
  end

  describe "metadata" do
    for {module, type, key, icon} <- @modules do
      test "#{inspect(module)} id/properties/calc_flags" do
        meta = unquote(module).metadata()
        assert meta.id == unquote(type)
        assert :buff in meta.properties
        assert unquote(key) in meta.calc_flags
      end

      test "#{inspect(module)} icon #{icon} resolves via Mmo.Efst" do
        assert unquote(module).metadata().icon == unquote(icon)
        assert is_integer(Efst.id(unquote(icon)))
      end
    end
  end

  test "both exp-boost effects are registered" do
    registered = Effects.all()

    for {module, _type, _key, _icon} <- @modules do
      assert module in registered
    end
  end
end
