defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaDispell do
  @moduledoc """
  Dispell (SA_DISPELL). Strips every dispellable status from one target at 9 cells
  with a 50% plus 10% per level chance, for 1 SP and a Yellow Gemstone spent either
  way. The removal itself lives in the shared dispel routine. A player or
  Homunculus target must be the caster's own, a party or guild member (or
  theirs), or an enemy; another fails when the cast ends, before anything is
  spent. No Soul Link gate is modelled yet.

  Renewal casts in 1.6 s plus 0.4 s fixed; pre-renewal in 2 s.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 289,
    no_target_self: true,
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
    item_cost: [%{id: 715, amount: 1}],
    target_hidden: true

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @default_rng &:rand.uniform/1

  @doc """
  The cast-end relation check: a player in the caster's party or guild, an
  enemy, the caster's own Homunculus or one whose master is such a player
  passes; any other player or Homunculus fails before anything is spent. A
  caster that is not a player may not aim at a Homunculus.
  """
  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), map()) ::
          :ok | {:error, :invalid_target}
  def validate(%PlayerState{} = caster, {:unit, {:homunculus, gid}}, _level, _definition) do
    case TargetResolver.resolve(:homunculus, gid) do
      {:ok, _pid, homunculus, :homunculus} -> homunculus_relation(caster, homunculus)
      _unresolved -> {:error, :invalid_target}
    end
  end

  def validate(_caster, {:unit, {:homunculus, _gid}}, _level, _definition),
    do: {:error, :invalid_target}

  def validate(%PlayerState{} = caster, {:unit, target_id}, _level, _definition)
      when is_integer(target_id) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, %PlayerState{} = target, _pid}} -> relation(caster, target, target)
      _not_a_player -> :ok
    end
  end

  def validate(_caster, _target, _level, _definition), do: :ok

  defp homunculus_relation(%{character_id: id}, %{owner_character_id: id}), do: :ok

  defp homunculus_relation(caster, %{owner_character_id: owner_id} = homunculus) do
    case UnitRegistry.get_unit(:player, owner_id) do
      {:ok, {_module, %PlayerState{} = owner, _pid}} -> relation(caster, owner, homunculus)
      _offline -> enemy(caster, homunculus)
    end
  end

  # A player passes as a party or guild member of the caster (by itself or as
  # a Homunculus's master), or as an enemy.
  defp relation(caster, player, target) do
    if shared?(caster.party_id, player.party_id) or shared?(caster.guild_id, player.guild_id),
      do: :ok,
      else: enemy(caster, target)
  end

  defp enemy(caster, target) do
    case Targeting.validate_enemy_relation_allow_dead(caster, target) do
      :ok -> :ok
      {:error, _reason} -> {:error, :invalid_target}
    end
  end

  defp shared?(id, id) when is_integer(id) and id > 0, do: true
  defp shared?(_caster_id, _owner_id), do: false

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
