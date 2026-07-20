defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaDispell do
  @moduledoc """
  Dispell (SA_DISPELL). Strips every dispellable status from a single target.

  Renewal data from rAthena `db/re/skill_db.yml:289`: max level 5, magic,
  no damage, range 9, 1600ms cast + 400ms fixed cast, one Yellow_Gemstone
  (715). `src/map/skills/mage/dispell.cpp:36-72` rolls `rnd()%100 >= 50+10*lv`
  to fail, i.e. a `50 + 10*lv`% success chance, and consumes the catalyst
  either way (the skill carries no `SKILL_NOCONSUME_REQ`).

  The removal itself lives in `Aesir.ZoneServer.Mmo.StatusEffect.Dispel`, which
  documents its own deviations from the reference - notably that Aesir has no
  `status_isimmune` (GTB) equivalent for `dispell.cpp:33`'s immunity gate.

  Deviations from the reference at this layer:

  * **No PvP/party gate.** `dispell.cpp:22-23` restricts a player-on-player
    Dispell outside PvP maps to party or duel members. Aesir has neither PvP
    maps nor duels, so `target_type: :target_any` mirrors the skill's
    unrestricted in-PvP reach; add the gate with PvP.
  * **No Soul Linker / SC_SPIRIT (Rogue) resistance** (`dispell.cpp:25-26`):
    Soul Linker is not implemented, an accepted limitation of this epic.
  * **No splash flag.** `skill_get_splash(SA_DISPELL, lv)` is unset in the
    renewal db, so the reference's `map_foreachinallrange` branch never runs
    for this skill; only the single-target path is modelled.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 289,
    name: :sa_dispell,
    display_name: "Dispell",
    max_level: 5,
    target_type: :target_any,
    damage_type: :no_damage,
    range: 9,
    sp_cost: List.duplicate(1, 5),
    cast_time: List.duplicate(1_600, 5),
    fixed_cast_time: List.duplicate(400, 5),
    item_cost: [%{id: 715, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @default_rng &:rand.uniform/1

  @doc """
  Rolls `50 + 10*lv`% and, on success, dispels the target.

  `opts` accepts `:rng`, a `(pos_integer() -> pos_integer())` function for the
  success roll, defaulting to `&:rand.uniform/1`.
  """
  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), map(), keyword()) ::
          {:ok, PlayerState.t()}
  def cast(caster, {:unit, target_id}, level, _definition, opts \\ []) do
    rng = Keyword.get(opts, :rng, @default_rng)

    if rng.(100) <= 50 + 10 * level do
      Dispel.dispel({target_unit_type(target_id), target_id})
    end

    {:ok, caster}
  end

  @spec target_unit_type(integer()) :: :mob | :player
  defp target_unit_type(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
  end
end
