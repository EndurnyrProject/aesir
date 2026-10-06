defmodule Aesir.ZoneServer.Mmo.Skills.HighWizard.HwMagiccrasher do
  @moduledoc """
  Stave Crasher (HW_MAGICCRASHER). A single neutral weapon strike at up to 9
  cells, resolved as a long-range physical hit and empowered by the caster's MATK.

  Renewal: a MATK value rolled from the caster's band is added to the weapon
  attack as flat ATK; 0.24 s cast plus 0.06 s fixed. Pre-renewal: the rolled MATK
  replaces the weapon attack and status ATK is not added; 0.3 s cast. Both modes:
  8 SP, 0.3 s after-cast delay, and the strike is always neutral whatever the
  weapon element.

  Monsters cast it through `mob_cast/5`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 365,
    name: :hw_magiccrasher,
    requires: [],
    display_name: "Stave Crasher",
    max_level: 1,
    ignore_noncrit_atk_bonus: [renewal: true, pre_renewal: false],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :neutral,
    range: 9,
    sp_cost: [8],
    cast_time: [renewal: [240], pre_renewal: [300]],
    fixed_cast_time: [renewal: [60], pre_renewal: []],
    after_cast_delay: [300]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @behaviour Active

  @doc """
  Strikes the target. `opts` accepts `:rng`, a `(pos_integer() -> pos_integer())`
  function for the MATK roll, defaulting to `&:rand.uniform/1`.
  """
  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t(), keyword()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition, opts \\ []) do
    with :ok <- strike(caster, target_id, level, definition, opts), do: {:ok, caster}
  end

  @impl Active
  @spec mob_cast(MobState.t(), term(), pos_integer(), Definition.t(), map()) ::
          :ok | {:error, atom()}
  def mob_cast(%MobState{} = caster, {:unit, type, id}, level, definition, _row) do
    strike(caster, {type, id}, level, definition, [])
  end

  @doc "Rolls a MATK value in the combatant's `[matk_min, matk_max)` band."
  @spec rolled_matk(map(), (pos_integer() -> pos_integer())) :: non_neg_integer()
  def rolled_matk(%{combat_stats: %{matk_min: min, matk_max: max}}, rng),
    do: min + rng.(max(max - min, 1)) - 1

  defp strike(caster, target, level, definition, opts) do
    rng = Keyword.get(opts, :rng, &:rand.uniform/1)
    rolled = caster |> caster.__struct__.to_combatant() |> rolled_matk(rng)

    attack_opts =
      [
        skill_id: definition.id,
        skill_level: level,
        element: :neutral,
        ranged: true,
        skip_range: true
      ] ++ matk_opts(GameMode.mode(), rolled)

    case Combat.execute_skill_attack(caster, target, attack_opts) do
      {:error, _reason} = error -> error
      _result -> :ok
    end
  end

  defp matk_opts(:renewal, rolled), do: [bonus_atk: rolled]
  defp matk_opts(:pre_renewal, rolled), do: [base_damage: rolled, skip_status_atk: true]
end
