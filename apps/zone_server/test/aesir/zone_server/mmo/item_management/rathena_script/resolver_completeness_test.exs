defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.ResolverCompletenessTest do
  @moduledoc """
  Guards the same-commit rule (architecture 4.1): a resolved status symbol with
  no registered effect module resolves at transpile time but fails at runtime
  with `{:error, :unknown_status}`. Every value in the resolver's `@statuses`
  map must have a registered `StatusEffect.Registry` definition.
  """
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry

  setup {Aesir.TestEtsSetup, :setup_ets_tables}

  test "every resolved status symbol has a registered Registry definition" do
    missing =
      for {symbol, status_id} <- Resolver.statuses(),
          is_nil(Registry.get_definition(status_id)),
          do: {symbol, status_id}

    assert missing == [],
           "resolver symbols with no registered effect module: #{inspect(missing)}"
  end

  test "every resolved Eff_ symbol has a registered Registry definition" do
    missing =
      for {symbol, status_id} <- Resolver.effs(),
          is_nil(Registry.get_definition(status_id)),
          do: {symbol, status_id}

    assert missing == [],
           "resolver Eff_ symbols with no registered effect module: #{inspect(missing)}"
  end
end
