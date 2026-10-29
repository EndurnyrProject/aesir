defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoChaincombo do
  @moduledoc """
  Raging Quadruple Blow (MO_CHAINCOMBO).

  Renewal: 250 plus 50 per level percent, doubled and split into six hits with
  a knuckle instead of four, for 4 plus level SP. Pre-renewal: 150 plus 50 per
  level percent split into four hits for 10 plus level SP.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 272,
    no_target_self: true,
    name: :mo_chaincombo,
    # Every weapon but a bow or a two-handed staff.
    require_weapon: [
      :fist,
      :dagger,
      :one_handed_sword,
      :two_handed_sword,
      :one_handed_spear,
      :two_handed_spear,
      :one_handed_axe,
      :two_handed_axe,
      :mace,
      :two_handed_mace,
      :staff,
      :knuckle,
      :musical,
      :whip,
      :book,
      :katar,
      :revolver,
      :rifle,
      :gatling,
      :shotgun,
      :grenade,
      :huuma
    ],
    display_name: "Raging Quadruple Blow",
    ignore_status_delay: true,
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -2,
    hit_count: -4,
    sp_cost: [renewal: [5, 6, 7, 8, 9], pre_renewal: [11, 12, 13, 14, 15]],
    after_cast_delay: List.duplicate(1_000, 5)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Root
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @doc """
  Starts only while Root holds the Monk or a Triple Attack window is open;
  otherwise it is refused silently.
  """
  @impl Active
  @spec begin_attempt(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :invalid_combo}
  def begin_attempt(%PlayerState{character_id: id} = caster, _target, _level, _definition) do
    if Root.rooted?(:player, id),
      do: {:ok, caster},
      else: with(:ok <- Combo.check(caster.combo, :quadruple, now()), do: {:ok, caster})
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    knuckle? = Stats.weapon_type(caster.stats.equipment) == :knuckle
    now = now()

    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: Formulas.quadruple_ratio(level, knuckle?),
      hit_divisions: Formulas.quadruple_hit_count(knuckle?),
      skip_crit: true
    ]

    with :ok <- Root.check_cast(:player, caster.character_id, definition.id),
         :ok <- Combat.execute_skill_attack(caster, target_id, opts),
         delay <- Enum.at(definition.after_cast_delay, level - 1, 0) do
      Combo.open_follow_up(caster, :quadruple, now, delay)
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_combo}

  defp now, do: System.monotonic_time(:millisecond)
end
