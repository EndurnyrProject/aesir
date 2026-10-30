defmodule Aesir.ZoneServer.Mmo.Skills.Whitesmith.WsCarttermination do
  @moduledoc """
  Cart Termination (WS_CARTTERMINATION). A cart-weight weapon strike requiring
  Cart Boost at player cast begin. Spends 15 SP and 500 plus 100 zeny per level
  without consuming the boost. Only Renewal applies Unfair Trick's discount.

  The cart ratio divides weight before multiplying and normalizing capacity;
  an empty player cart instead uses 100%, and monsters use a fixed load ratio.
  Surviving connected hits may stun at 5% per level for 4.5 seconds in Renewal
  or 5 seconds in pre-renewal, subject to normal resistance and immunity.

  Classic bypasses attack cards, Guard and Cicada. Both modes bypass Parrying,
  Energy Coat and Reflect Shield's status return, not equipment damage returns.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 485,
    name: :ws_carttermination,
    display_name: "Cart Termination",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -2,
    sp_cost: [15, 15, 15, 15, 15, 15, 15, 15, 15, 15],
    zeny_cost: [600, 700, 800, 900, 1_000, 1_100, 1_200, 1_300, 1_400, 1_500],
    ignore_atk_card: [renewal: false, pre_renewal: true],
    ignore_auto_guard: [renewal: false, pre_renewal: true],
    ignore_cicada: [renewal: false, pre_renewal: true],
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
    ]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Cart.Weight
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @doc "Requires Cart Boost at player cast begin, without adding a second cart check."
  @impl Active
  @spec begin_attempt(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, :skill_failed}
  def begin_attempt(%PlayerState{character_id: id} = caster, _target, _level, _definition) do
    if StatusStorage.has_status?(:player, id, :sc_cartboost),
      do: {:ok, caster},
      else: {:error, :skill_failed}
  end

  def begin_attempt(caster, _target, _level, _definition), do: {:ok, caster}

  @doc "Returns the integer weapon ratio, preserving the empty-cart branch and divide order."
  @spec skill_ratio(:player | :non_player, pos_integer(), non_neg_integer(), pos_integer()) ::
          non_neg_integer()
  def skill_ratio(:non_player, level, _weight, _capacity), do: div(80_000, denominator(level))
  def skill_ratio(:player, _level, 0, _capacity), do: 100

  def skill_ratio(:player, level, weight, capacity),
    do: div(div(weight, denominator(level)) * 80_000, capacity)

  defp denominator(level), do: max(10 * (16 - level), 1)

  @doc "Executes the paid weapon hit and its native surviving-hit stun."
  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_ref}, level, definition) do
    case Combat.execute_skill_attack(caster, target_ref,
           skill_id: definition.id,
           skill_level: level,
           skill_ratio: caster_ratio(caster, level),
           skip_crit: true,
           skip_range: true,
           report_hit: true
         ) do
      {:ok, %{hit?: true, target_survives?: true}} ->
        stun(caster, target_ref, level)
        {:ok, caster}

      {:ok, _report} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  @doc "Uses the non-player ratio and raw typed monster target, without player requirements."
  @impl Active
  @spec mob_cast(MobState.t(), {:unit, atom(), integer()}, pos_integer(), Definition.t(), map()) ::
          :ok | {:error, atom()}
  def mob_cast(caster, {:unit, type, id}, level, definition, _row) do
    case cast(caster, {:unit, {type, id}}, level, definition) do
      {:ok, _caster} -> :ok
      {:error, _reason} = error -> error
    end
  end

  defp caster_ratio(%PlayerState{cart: cart}, level),
    do: skill_ratio(:player, level, Weight.current_weight(cart), Weight.max_weight())

  defp caster_ratio(_caster, level), do: skill_ratio(:non_player, level, 0, Weight.max_weight())

  defp stun(caster, target_ref, level) do
    with {:ok, target} <- Combat.resolve_combatant(target_ref) do
      Interpreter.apply_status(target.unit_type, target.unit_id, :sc_stun,
        val1: level,
        success_rate: 5 * level,
        duration: if(GameMode.mode() == :renewal, do: 4_500, else: 5_000),
        caster_id: caster.__struct__.get_unit_id(caster),
        source_type: caster.__struct__.get_unit_type(caster)
      )
    end
  end
end
