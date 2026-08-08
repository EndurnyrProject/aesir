defmodule Aesir.ZoneServer.Mmo.StatusEffect.EndOnStartTest do
  @moduledoc """
  Guards `end_on_start` lists against ids that resolve to no status.

  Such an id is silently inert: the interpreter iterates the list and ends
  nothing, so a status meant to replace another quietly stacks with it. It also
  reads as evidence that the named status exists, which is how `:sc_enchantarms`
  was long mistaken for a real endow.

  Ids for statuses that are genuinely not implemented yet are allowlisted below
  rather than left unguarded, so that a *new* unresolvable id still fails.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry

  # Real statuses that no module implements yet. Every reference to one is a
  # correct forward reference and starts working the day the status lands.
  @unimplemented [
    :sc_acceleration,
    :sc_adoramus,
    :sc_cartboost,
    :sc_ghostweapon,
    :sc_gn_cartboost,
    :sc_magneticfield,
    :sc_merc_quicken,
    :sc_onehand,
    :sc_offertorium,
    :sc_shadowweapon,
    :sc_truesight,
    :sc_windwalk
  ]

  @allowed @unimplemented

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  test "every end_on_start id resolves to a registered status" do
    unresolvable =
      for module <- Effects.all(),
          status_id <- module.metadata().end_on_start,
          status_id not in @allowed,
          Registry.get_definition(status_id) == nil,
          do: {module, status_id}

    assert unresolvable == []
  end

  test "the allowlist only covers statuses that really are missing" do
    stale = Enum.filter(@allowed, &(Registry.get_definition(&1) != nil))

    assert stale == [],
           "#{inspect(stale)} now exist(s) and must be removed from the allowlist"
  end
end
