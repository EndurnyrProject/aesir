defmodule Aesir.ZoneServer.Mmo.Skills.Clown.Tarot do
  @moduledoc """
  Tarot eligibility, success gate and card effects over existing unit boundaries.

  Both modes use the weighted deck and an eight-percent-per-level success chance.
  The Emperium is refused. Pre-renewal additionally refuses Basilica holders;
  renewal's Sun grants a marker preventing further cards for thirty seconds.
  Unit mutations remain in the target's session and statuses use normal resistance.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skills.Clown.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Clown.TarotDeck
  alias Aesir.ZoneServer.Mmo.StatusEffect.ClearBuffs
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.Resource
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Refuses protected targets, rolls success, and plays one card."
  @spec play(struct(), Ref.t(), pos_integer()) ::
          {:ok, TarotDeck.card()} | {:error, :immune | :failed | :invalid_target}
  def play(caster, {type, id} = target, level) do
    with false <- StatusStorage.has_status?(type, id, :sc_tarotcard),
         :ok <- eligible(target),
         true <- Formulas.tarot_success?(level, &TarotDeck.roll/1) do
      card = TarotDeck.draw()
      apply(card, caster, target, level)
      {:ok, card}
    else
      true -> {:error, :immune}
      false -> {:error, :failed}
      {:error, _} = error -> error
    end
  end

  @doc "Applies a drawn card through combat, resource and status-effect boundaries."
  @spec apply(TarotDeck.card(), struct(), Ref.t(), pos_integer()) :: :ok
  def apply(:fool, _caster, target, _level), do: Resource.drain_sp_percent(target, 100)

  def apply(:high_priestess, _caster, target, _level) do
    ClearBuffs.clear(target, [:buffs, :chem_protect])
  end

  def apply(:magician, caster, target, _level),
    do: status(caster, target, :sc_incmatkrate, val1: -50, duration: 30_000)

  def apply(:strength, caster, target, _level),
    do: status(caster, target, :sc_incatkrate, val1: -50, duration: 30_000)

  def apply(:sun, caster, target, _level) do
    for id <- [:sc_incatkrate, :sc_incmatkrate, :sc_inchitrate, :sc_incfleerate, :sc_incdefrate],
        do: status(caster, target, id, val1: -20, duration: 30_000)

    if GameMode.mode() == :renewal, do: status(caster, target, :sc_tarotcard, duration: 30_000)
    :ok
  end

  def apply(:chariot, caster, target, level) do
    if fixed_hit(caster, target, level, 1000), do: break_equipment(target)
    :ok
  end

  def apply(:devil, caster, target, level) do
    if fixed_hit(caster, target, level, 6666) do
      apply(:strength, caster, target, level)
      apply(:magician, caster, target, level)
      status(caster, target, :sc_curse, [])
    end

    :ok
  end

  def apply(:tower, caster, target, level) do
    fixed_hit(caster, target, level, 4444)
    :ok
  end

  def apply(:lovers, caster, {type, id}, _level) do
    {_source_type, source_id} = caster_ref(caster)
    DamageApplication.apply_heal(type, id, 2000, source_id)

    with {:ok, {_module, unit, pid}} when is_pid(pid) <- UnitRegistry.get_unit(type, id),
         true <- Unit.living?(unit),
         false <- Targeting.versus_map?(unit.map_name) do
      warp(type, unit, pid)
    end

    :ok
  end

  def apply(:wheel_of_fortune, caster, target, level),
    do: Enum.each(1..2, fn _ -> apply(TarotDeck.draw(), caster, target, level) end)

  def apply(:hanged_man, caster, target, _level) do
    id = Enum.random([:sc_ankle, :sc_freeze, :sc_stonewait])
    params = if id == :sc_ankle, do: [duration: 30_000], else: []
    status(caster, target, id, params)
  end

  def apply(:death, caster, {type, id} = target, _level) do
    with {:ok, {_module, unit, pid}} when is_pid(pid) <- UnitRegistry.get_unit(type, id),
         true <- Unit.living?(unit),
         false <- status_immune?(unit) do
      coma(type, pid, caster_ref(caster))
    end

    status(caster, target, :sc_curse, [])
    status(caster, target, :sc_poison, [])
  end

  def apply(:temperance, caster, target, _level),
    do: status(caster, target, :sc_confusion, duration: 30_000)

  def apply(:star, caster, target, _level), do: status(caster, target, :sc_stun, [])

  defp warp(:player, %{map_name: map}, pid) do
    case Cell.random_traversable(map) do
      {:ok, {x, y}} -> PlayerSession.warp(pid, map, x, y)
      {:error, _} -> :ok
    end
  end

  defp warp(:mob, _unit, pid), do: MobSession.teleport(pid)
  defp warp(_type, _unit, _pid), do: :ok

  defp coma(:player, pid, source), do: PlayerSession.apply_coma(pid, source)
  defp coma(:mob, pid, source), do: MobSession.apply_coma(pid, source)
  defp coma(_type, _pid, _source), do: :ok

  # SC_COMA is BossResist: a status-immune monster resists it.
  defp status_immune?(%MobState{} = mob), do: MobState.status_immune?(mob)
  defp status_immune?(_unit), do: false

  defp caster_ref(caster) do
    adapter = Caster.for(caster)
    {adapter.unit_type(caster), adapter.id(caster)}
  end

  defp fixed_hit(caster, target, level, damage) do
    case Combat.execute_misc_attack(caster, target,
           skill_id: 489,
           skill_level: level,
           base_damage: damage,
           ignore_element: true,
           fix_damage: true,
           report_hit: true
         ) do
      {:ok, %{target_survives?: true}} -> true
      _ -> false
    end
  end

  defp break_equipment({:player, id}) do
    with {:ok, {_module, %PlayerState{stats: stats} = player, pid}} when is_pid(pid) <-
           UnitRegistry.get_unit(:player, id),
         true <- Unit.living?(player) do
      slot = Enum.random([:armor, :shield, :helm])

      10_000
      |> EquipBreak.resolve_slot({:player, id, stats}, slot)
      |> Enum.each(fn {:target, broken_slot} -> PlayerSession.break_equip(pid, broken_slot) end)
    end

    :ok
  end

  defp break_equipment(_target), do: :ok

  defp status(caster, {type, id}, status_id, params) do
    {source_type, source_id} = caster_ref(caster)
    opts = [caster_id: source_id, source_type: source_type, owner_refresh: :notify]
    StatusInterpreter.apply_status(type, id, status_id, Keyword.merge(opts, params))
    :ok
  end

  defp eligible({type, id}) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, %MobState{mob_id: 1288}, _pid}} ->
        {:error, :invalid_target}

      {:ok, {_module, unit, _pid}} ->
        cond do
          not Unit.living?(unit) ->
            {:error, :invalid_target}

          GameMode.mode() == :pre_renewal and StatusStorage.has_status?(type, id, :sc_basilica) ->
            {:error, :invalid_target}

          true ->
            :ok
        end

      _ ->
        {:error, :invalid_target}
    end
  end
end
