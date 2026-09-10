defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaDispell do
  @moduledoc """
  Dispell (SA_DISPELL). Strips every dispellable status from one target at 9 cells
  with a 50% plus 10% per level chance, for 1 SP and a Yellow Gemstone spent either
  way. The removal itself lives in the shared dispel routine. No PvP, party, or Soul
  Link gate is modelled yet.

  Renewal casts in 1.6 s plus 0.4 s fixed; pre-renewal in 2 s.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 289,
    name: :sa_dispell,
    requires: [],
    display_name: "Dispell",
    max_level: 5,
    target_type: :target_any,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    sp_cost: List.duplicate(1, 5),
    cast_time: [renewal: List.duplicate(1_600, 5), pre_renewal: List.duplicate(2_000, 5)],
    fixed_cast_time: [renewal: List.duplicate(400, 5), pre_renewal: []],
    item_cost: [%{id: 715, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @default_rng &:rand.uniform/1

  @impl Active
  def validate(%{character_id: caster_id}, {:unit, {:homunculus, gid}}, _level, _definition) do
    with {:ok, caster_combatant} <- TargetResolver.resolve_combatant(:player, caster_id),
         {:ok, target_combatant} <- TargetResolver.resolve_combatant(:homunculus, gid),
         true <- Targeting.direct_support?(caster_combatant, target_combatant) do
      :ok
    else
      _ -> {:error, :invalid_target}
    end
  end

  def validate(_caster, {:unit, {:homunculus, _gid}}, _level, _definition),
    do: {:error, :invalid_target}

  def validate(_caster, _target, _level, _definition), do: :ok

  @doc """
  Rolls `50 + 10*lv`% and, on success, dispels the target.

  `opts` accepts `:rng`, a `(pos_integer() -> pos_integer())` function for the
  success roll, defaulting to `&:rand.uniform/1`.
  """
  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), map(), keyword()) ::
          {:ok, PlayerState.t()}
  def cast(caster, {:unit, target}, level, _definition, opts \\ []) do
    rng = Keyword.get(opts, :rng, @default_rng)

    if rng.(100) <= 50 + 10 * level do
      Dispel.dispel(target_ref(target))
    end

    {:ok, caster}
  end

  defp target_ref({unit_type, unit_id}), do: {unit_type, unit_id}

  defp target_ref(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id),
      do: {:mob, target_id},
      else: {:player, target_id}
  end
end
