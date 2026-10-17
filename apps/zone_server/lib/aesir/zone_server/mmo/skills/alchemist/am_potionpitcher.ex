defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPotionpitcher do
  @moduledoc """
  Potion Pitcher (AM_POTIONPITCHER).

  A player throws the level's potion (Red, Orange, Yellow, White, then Blue) at
  itself, a party or guild member, or its own Homunculus for 1 SP with a 0.5 s
  delay. The thrower reads the potion's script amounts without healing anyone
  and computes the whole recovery with `Combat.PotionRecovery`; a deferred
  descriptor settles the potion and the cast costs, then the recipient takes the
  result as a plain heal (Frenzy refuses the HP).

  A monster throws its level's table amount on itself or a friend, with no
  potion; a throw at the Emperium heals nothing. A player can never target the
  Emperium (only itself, its allies and its own Homunculus).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 231,
    name: :am_potionpitcher,
    requires: [],
    display_name: "Potion Pitcher",
    max_level: 5,
    target_type: :target_ally,
    damage_type: :no_damage,
    range: 9,
    sp_cost: List.duplicate(1, 5),
    after_cast_delay: List.duplicate(500, 5),
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.PotionRecovery
  alias Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @potions %{1 => 501, 2 => 502, 3 => 503, 4 => 504, 5 => 505}
  @emperium 1_288

  # CompiledItemScripts is created at runtime by ScriptCompiler.compile_all!/1.
  @compile {:no_warn_undefined, CompiledItemScripts}

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :invalid_target}
  def validate(%PlayerState{character_id: id}, target, _level, _definition)
      when target in [:self, {:unit, id}],
      do: :ok

  def validate(%PlayerState{} = caster, {:unit, {:player, target_id}}, level, definition),
    do: validate(caster, {:unit, target_id}, level, definition)

  def validate(%PlayerState{} = caster, {:unit, {:homunculus, gid}}, _level, _definition) do
    case UnitRegistry.get_unit(:homunculus, gid) do
      {:ok, {HomunculusState, %HomunculusState{} = target, _pid}} ->
        if Unit.living?(target) and Targeting.direct_support?(caster, target),
          do: :ok,
          else: {:error, :invalid_target}

      _other ->
        {:error, :invalid_target}
    end
  end

  def validate(%PlayerState{} = caster, {:unit, target_id}, _level, _definition)
      when is_integer(target_id) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {PlayerState, %PlayerState{} = target, _pid}} ->
        if Unit.living?(target) and allied?(caster, target),
          do: :ok,
          else: {:error, :invalid_target}

      _other ->
        {:error, :invalid_target}
    end
  end

  def validate(%MobState{}, _target, _level, _definition), do: :ok

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(PlayerState.t() | MobState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:deferred, PlayerState.t(), tuple()} | {:ok, MobState.t()} | {:error, atom()}
  def cast(%PlayerState{} = caster, target, level, definition) do
    item_id = potion_for_level(level)

    with :ok <- validate(caster, target, level, definition),
         index when not is_nil(index) <- ItemContainer.stackable_index(caster.inventory, item_id),
         {:ok, recipient} <- recipient(caster, target),
         {:ok, potion} <- read_potion(caster, item_id),
         {:ok, inventory, change} <- ItemContainer.remove(caster.inventory, index, 1) do
      {hp, sp} = PotionRecovery.player_throw(PotionRecovery.thrower(caster), recipient, potion)

      updated = %{
        caster
        | inventory: inventory,
          pending_inventory_persist:
            caster.pending_inventory_persist ++ [{caster.inventory, inventory, change}]
      }

      {:deferred, updated, {:potion_delivery, recipient.ref, {:potion, hp, sp}}}
    else
      nil -> {:error, :missing_potion}
      {:error, :not_found} -> {:error, :missing_potion}
      {:error, :insufficient_amount} -> {:error, :missing_potion}
      {:error, _reason} = error -> error
    end
  end

  def cast(%MobState{} = caster, target, level, _definition) do
    case mob_recipient(caster, Active.target_unit_ref(caster, target)) do
      :emperium ->
        {:ok, caster}

      {:ok, recipient} ->
        {hp, sp} = PotionRecovery.monster_throw(level, recipient)
        deliver_from_mob(recipient.ref, hp, sp, caster.instance_id)
        {:ok, caster}

      :error ->
        {:error, :invalid_target}
    end
  end

  @doc "The potion a player throws at `level`."
  @spec potion_for_level(1..5) :: 501..505
  def potion_for_level(level), do: Map.fetch!(@potions, level)

  @doc """
  Reads the amounts `item_id`'s script declares when thrown: the last flat
  (`itemheal`) and the last percent (`percentheal`) heal, each rolled once.
  """
  @spec read_potion(PlayerState.t(), pos_integer()) ::
          {:ok, PotionRecovery.potion()} | {:error, term()}
  def read_potion(%PlayerState{} = caster, item_id) do
    ctx = %Ctx{
      char_id: caster.character_id,
      account_id: caster.account_id,
      connection_pid: nil,
      game_state: caster,
      source: {:potion_pitch, item_id}
    }

    case CompiledItemScripts.on_use(item_id, ctx) do
      %Ctx{status: {:error, _reason} = error} ->
        error

      %Ctx{session_effects: effects} ->
        {:ok, Enum.reduce(effects, %{hp: 0, sp: 0, per_hp: 0, per_sp: 0}, &record/2)}
    end
  end

  defp record({:potion_pitch, :flat, hp, sp}, potion), do: %{potion | hp: hp, sp: sp}
  defp record({:potion_pitch, :percent, hp, sp}, potion), do: %{potion | per_hp: hp, per_sp: sp}
  defp record(_effect, potion), do: potion

  defp recipient(%PlayerState{character_id: id} = caster, target)
       when target in [:self, {:unit, id}, {:unit, {:player, id}}],
       do: {:ok, PotionRecovery.recipient(caster)}

  defp recipient(_caster, {:unit, {:homunculus, gid}}), do: registered(:homunculus, gid)
  defp recipient(_caster, {:unit, {:player, id}}), do: registered(:player, id)
  defp recipient(_caster, {:unit, id}) when is_integer(id), do: registered(:player, id)

  defp registered(type, id) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, state, _pid}} -> {:ok, PotionRecovery.recipient(state)}
      _missing -> {:error, :invalid_target}
    end
  end

  defp mob_recipient(%MobState{instance_id: id} = caster, {:mob, id}), do: throw_at(caster)

  defp mob_recipient(_caster, {type, id}) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, state, _pid}} -> throw_at(state)
      _missing -> :error
    end
  end

  defp throw_at(%MobState{mob_data: %{id: @emperium}}), do: :emperium
  defp throw_at(state), do: {:ok, PotionRecovery.recipient(state)}

  defp deliver_from_mob({:mob, id}, hp, _sp, source_id),
    do: Combat.apply_heal(:mob, id, hp, source_id)

  defp deliver_from_mob({type, id}, hp, sp, source_id),
    do: Combat.apply_heal(type, id, {:potion, hp, sp}, source_id)

  defp allied?(%PlayerState{} = caster, %PlayerState{} = target) do
    (caster.party_id != 0 and caster.party_id == target.party_id) or
      (caster.guild_id != 0 and caster.guild_id == target.guild_id)
  end
end
