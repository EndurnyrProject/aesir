defmodule Aesir.ZoneServer.Mmo.Combat.PotionRecovery do
  @moduledoc """
  The HP and SP a Potion Pitcher throw restores, computed in full by the thrower.
  The recipient only applies the result as a plain heal: Frenzy refuses the HP
  and nothing else scales it.

  A player throw starts from the potion's script amounts. A percent potion takes
  that percent of the recipient's maximum HP (and, for a player recipient, SP)
  scaled by `100 + 10 * Potion Pitcher + 5 * Potion Research` (learned levels).
  A flat potion scales the amount by the same rate, then by the recipient's
  `100 + 2 * VIT` (`2 * INT` for SP) and, for a player recipient, by `100 + 10 *
  Increase HP Recovery` (`Increase SP Recovery` for SP). Then the thrower's
  potion item-group heal rates, the thrower's heal power and Potion Pitcher heal
  bonus, and a player recipient's received heal power and Potion Pitcher
  received bonus each add their percent.

  A monster throw rolls a level table (45, 105, 175, then 325) plus up to `20 *
  level`, scales it by `150 + 10 * level` percent, then by the recipient's VIT
  and a player recipient's Increase HP Recovery and received heal bonuses.

  Both then add the thrower's H.Plus (players only), and the recipient's No
  Recovery cancels both. In renewal a Homunculus recipient takes three times the
  HP, and Asura recovery cancels the SP. Every step truncates on its own.

  Not modelled, as their statuses do not exist yet: the Soul Link Alchemist
  base-level bonus, Water Insignia, Critical Wound and Death Hurt.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Ref

  @sm_recovery 4
  @mg_srecovery 9
  @potion_pitcher 231
  @learning_potion 227

  @typedoc "The amounts a potion's script declared: flat (`itemheal`) and percent (`percentheal`)."
  @type potion :: %{
          hp: integer(),
          sp: integer(),
          per_hp: integer(),
          per_sp: integer()
        }

  @typedoc "What a player throw reads from the thrower."
  @type thrower :: %{
          pitcher: non_neg_integer(),
          learning_potion: non_neg_integer(),
          group_hp_rate: integer(),
          group_sp_rate: integer(),
          skill_heal: integer(),
          hplus: integer()
        }

  @typedoc "What a throw reads from the recipient."
  @type recipient :: %{
          ref: Ref.t(),
          player?: boolean(),
          vit: integer(),
          int: integer(),
          max_hp: non_neg_integer(),
          max_sp: non_neg_integer(),
          hp_recovery: non_neg_integer(),
          sp_recovery: non_neg_integer(),
          received_heal: integer()
        }

  @doc "Reads a player thrower's terms."
  @spec thrower(PlayerState.t()) :: thrower()
  def thrower(%PlayerState{stats: stats}) do
    %{
      pitcher: learned(stats, @potion_pitcher),
      learning_potion: learned(stats, @learning_potion),
      group_hp_rate: equipment(stats, {:add_item_group_heal, :potion}),
      group_sp_rate: equipment(stats, {:add_item_group_sp_heal, :potion}),
      skill_heal:
        equipment(stats, :heal_power) + equipment(stats, {:skill_heal, @potion_pitcher}),
      hplus: Map.get(stats.combat_stats, :hplus, 0)
    }
  end

  @doc "Reads a recipient's terms from its live state."
  @spec recipient(PlayerState.t() | HomunculusState.t() | MobState.t()) :: recipient()
  def recipient(%PlayerState{character_id: id, stats: stats}) do
    %{
      ref: {:player, id},
      player?: true,
      vit: PlayerStats.get_effective_stat(stats, :vit),
      int: PlayerStats.get_effective_stat(stats, :int),
      max_hp: stats.derived_stats.max_hp,
      max_sp: stats.derived_stats.max_sp,
      hp_recovery: learned(stats, @sm_recovery),
      sp_recovery: learned(stats, @mg_srecovery),
      received_heal:
        equipment(stats, :heal_power2) + equipment(stats, {:skill_heal2, @potion_pitcher})
    }
  end

  def recipient(%HomunculusState{} = homunculus) do
    unit(
      {:homunculus, homunculus.world_gid},
      homunculus.vit,
      homunculus.int,
      homunculus.max_hp,
      homunculus.max_sp
    )
  end

  def recipient(%MobState{} = mob) do
    %{base_stats: stats} = MobState.to_combatant(mob)
    unit({:mob, mob.instance_id}, stats.vit, stats.int, mob.max_hp, 0)
  end

  defp unit(ref, vit, int, max_hp, max_sp) do
    %{
      ref: ref,
      player?: false,
      vit: vit,
      int: int,
      max_hp: max_hp,
      max_sp: max_sp,
      hp_recovery: 0,
      sp_recovery: 0,
      received_heal: 0
    }
  end

  @doc "The `{hp, sp}` a player's throw of `potion` restores on `recipient`."
  @spec player_throw(thrower(), recipient(), potion()) :: {integer(), integer()}
  def player_throw(thrower, recipient, potion) do
    rate = 100 + 10 * thrower.pitcher + 5 * thrower.learning_potion

    {hp, sp} = base(potion, rate, recipient)

    {percent(hp, thrower.group_hp_rate), percent(sp, thrower.group_sp_rate)}
    |> both(thrower.skill_heal)
    |> finish(recipient, thrower.hplus)
  end

  @doc "The `{hp, sp}` a monster's throw at `level` restores on `recipient`."
  @spec monster_throw(pos_integer(), recipient()) :: {integer(), integer()}
  def monster_throw(level, recipient) do
    base =
      case level do
        1 -> 45
        2 -> 105
        3 -> 175
        _level -> 325
      end

    hp = div((base + :rand.uniform(level * 20 + 1) - 1) * (150 + level * 10), 100)

    {stat_scaled(hp, recipient.vit, recipient, recipient.hp_recovery), 0}
    |> finish(recipient, 0)
  end

  defp base(%{per_hp: per_hp, per_sp: per_sp}, rate, recipient) when per_hp > 0 or per_sp > 0 do
    hp = div(div(recipient.max_hp * per_hp, 100) * rate * 100, 10_000)

    sp =
      if recipient.player?,
        do: div(div(recipient.max_sp * per_sp, 100) * rate * 100, 10_000),
        else: 0

    {hp, sp}
  end

  defp base(potion, rate, recipient) do
    {flat(potion.hp, rate, recipient.vit, recipient, recipient.hp_recovery),
     flat(potion.sp, rate, recipient.int, recipient, recipient.sp_recovery)}
  end

  defp flat(amount, rate, stat, recipient, recovery) when amount > 0,
    do: amount |> Kernel.*(rate * 100) |> div(10_000) |> stat_scaled(stat, recipient, recovery)

  defp flat(_amount, _rate, _stat, _recipient, _recovery), do: 0

  defp stat_scaled(amount, stat, recipient, recovery) do
    amount = div(amount * (100 + stat * 2), 100)
    if recipient.player?, do: div(amount * (100 + recovery * 10), 100), else: amount
  end

  defp finish(amounts, recipient, hplus) do
    renewal? = GameMode.mode() == :renewal
    {type, id} = recipient.ref

    {hp, sp} =
      amounts
      |> both(if recipient.player?, do: recipient.received_heal, else: 0)
      |> both(if hplus > 0, do: hplus, else: 0)

    {hp, sp} =
      if StatusStorage.has_status?(type, id, :sc_norecover_state), do: {0, 0}, else: {hp, sp}

    hp = if renewal? and type == :homunculus, do: hp * 3, else: hp

    if renewal? and StatusStorage.has_status?(type, id, :sc_extremityfist),
      do: {hp, 0},
      else: {hp, sp}
  end

  defp both({hp, sp}, rate), do: {percent(hp, rate), percent(sp, rate)}

  defp percent(amount, 0), do: amount
  defp percent(amount, rate), do: amount + div(amount * rate, 100)

  defp learned(stats, skill_id),
    do: Learned.learned_level(stats.progression.learned_skills, skill_id)

  defp equipment(stats, key), do: PlayerStats.get_equipment_modifier(stats, key)
end
