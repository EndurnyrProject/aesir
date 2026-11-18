defmodule Aesir.ZoneServer.Unit.Pet.Handlers.CatchHandler do
  @moduledoc """
  The catch process: a taming item parks the lure and opens the client's target
  cursor, and the client's pick rolls the capture.

  One process per character lives in `pet_runtime.catch_process`, so a new
  taming item replaces it and it survives the pet coming out or going back.
  Every pick answers with a `PetCatchResult` and ends the process.
  """

  alias Aesir.Net.ChatNotice
  alias Aesir.Net.PetCatchResult
  alias Aesir.Net.PetCatchStart
  alias Aesir.Net.SystemNotice
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.PetDefinition
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.PlayerEvents
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit, as: PlayerStateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @catch_refusal "You can't catch any pet on this map."
  @hiding_statuses [:sc_hiding, :sc_cloaking, :sc_camouflage, :sc_newmoon, :sc_cloakingexceed]
  @roll_base 10_000
  @uint32_range 0x1_0000_0000

  @doc """
  Starts a catch with `lure_id` and `flag` (0 the lure must be the pet's taming
  item, 1 any mob that is not status-immune, 2 any mob). On a `nopetcapture`
  map only message 669 is sent and a running process is left as it was.
  """
  @spec start(SessionState.t(), pos_integer(), 0..2) :: SessionState.t()
  def start(%SessionState{game_state: owner, pet_runtime: runtime} = session, lure_id, flag) do
    if MapFlags.get(owner.map_name, :nopetcapture) do
      send_catch_refusal(session)
      session
    else
      MessageRouter.send_to(session.connection_pid, %PetCatchStart{})
      %{session | pet_runtime: %{runtime | catch_process: %{lure_id: lure_id, flag: flag}}}
    end
  end

  @doc """
  Finishes the catch on the picked mob. With no process only a failed result
  is sent. Otherwise the process ends and the catch fails, in this order, for
  a mob that is gone or dead, a `nopetcapture` map (message 669), a mob no pet
  hatches from, a lure the flag refuses, a mob beyond `pet_distance_check`, a
  full inventory (the item-count notice) and, with `pet_hide_check`, a hidden
  mob. Then `capture_rate/3` is rolled out of 10,000 with `roll` (given the
  base, it returns 1..base): a success captures the mob and puts the new pet's
  egg in the inventory.
  """
  @spec finish(SessionState.t(), pos_integer(), (pos_integer() -> pos_integer())) ::
          SessionState.t()
  def finish(session, target_gid, roll \\ &:rand.uniform/1)

  def finish(%SessionState{pet_runtime: %{catch_process: nil}} = session, _target_gid, _roll) do
    send_result(session, false)
    session
  end

  def finish(%SessionState{pet_runtime: runtime} = session, target_gid, roll) do
    process = runtime.catch_process
    session = %{session | pet_runtime: %{runtime | catch_process: nil}}

    with {:ok, mob, pid} <- live_mob(target_gid),
         :ok <- capture_allowed(session),
         {:ok, definition} <- Catalog.by_mob(mob.mob_id),
         {:ok, species} <- Mobs.by_id(definition.mob_id),
         :ok <- lure_fits(process, definition, mob),
         :ok <- within_reach(session.game_state, mob),
         :ok <- inventory_room(session),
         :ok <- visible(mob),
         true <- roll.(@roll_base) <= rate_against(definition, session.game_state, mob),
         :ok <- MobSession.capture(pid) do
      send_result(session, true)
      grant_egg(session, definition, species)
    else
      {:refused, notice} ->
        send_result(session, false)
        notice.(session)
        session

      _failed ->
        send_result(session, false)
        session
    end
  end

  @doc """
  The capture chance out of 10,000. The default formula grows the pet's
  capture rate as the mob's HP falls; the legacy one also weighs the level gap
  and the owner's LUK in unsigned 32-bit arithmetic, so a negative sum wraps
  into a near-certain rate. The HP percentage is truncated from a
  floating-point ratio, the rate is at least 1 and `pet_catch_rate` then
  scales it.
  """
  @spec capture_rate(
          PetDefinition.t(),
          %{base_level: integer(), luk: integer()},
          %{level: integer(), hp: integer(), max_hp: integer()}
        ) :: non_neg_integer()
  def capture_rate(%PetDefinition{capture_rate: capture}, owner, mob) do
    hp_percent = floor(100 * (mob.hp / mob.max_hp))

    rate =
      if Config.pet_legacy_formula?(),
        do:
          div(
            Integer.mod(
              (capture + (owner.base_level - mob.level) * 30 + owner.luk * 20) *
                (200 - hp_percent),
              @uint32_range
            ),
            100
          ),
        else: capture + div((100 - hp_percent) * capture, 100)

    scale(max(rate, 1), Config.pet_catch_rate())
  end

  defp scale(rate, 100), do: rate
  defp scale(rate, percent), do: div(rate * percent, 100)

  defp rate_against(definition, owner, mob) do
    capture_rate(
      definition,
      %{
        base_level: owner.stats.progression.base_level,
        luk: Stats.get_effective_stat(owner.stats, :luk)
      },
      %{level: MobState.get_level(mob), hp: mob.hp, max_hp: mob.calculated.max_hp}
    )
  end

  defp live_mob(gid) do
    with {:ok, {_module, %MobState{} = mob, pid}} <- UnitRegistry.get_unit(:mob, gid),
         true <- MobState.living?(mob) do
      {:ok, mob, pid}
    end
  end

  defp capture_allowed(%SessionState{game_state: owner}) do
    if MapFlags.get(owner.map_name, :nopetcapture),
      do: {:refused, &send_catch_refusal/1},
      else: :ok
  end

  defp lure_fits(%{flag: 0, lure_id: lure_id}, %PetDefinition{tame_item_id: lure_id}, _mob),
    do: :ok

  defp lure_fits(%{flag: 0}, _definition, _mob), do: :wrong_lure

  defp lure_fits(%{flag: 1}, _definition, mob),
    do: if(MobState.status_immune?(mob), do: :status_immune, else: :ok)

  defp lure_fits(_process, _definition, _mob), do: :ok

  defp within_reach(owner, mob) do
    limit = Config.pet_distance_check()

    if limit > 0 and Geometry.chebyshev_distance(owner.x, owner.y, mob.x, mob.y) > limit,
      do: :too_far,
      else: :ok
  end

  defp inventory_room(%SessionState{game_state: owner}) do
    if Inventory.blank_slots(owner.inventory) > 0,
      do: :ok,
      else: {:refused, &send_count_notice/1}
  end

  defp visible(%MobState{instance_id: id}) do
    if Config.pet_hide_check?() and
         Enum.any?(@hiding_statuses, &StatusStorage.has_status?(:mob, id, &1)),
       do: :hidden,
       else: :ok
  end

  defp grant_egg(%SessionState{game_state: owner} = session, definition, species) do
    room = Inventory.weight_room(owner.inventory, owner.stats)

    case Persistence.create_with_egg(
           owner.account_id,
           owner.character_id,
           definition,
           species,
           owner.inventory,
           room
         ) do
      {:ok, inventory, _pet} ->
        InventoryManager.notify_new_rows(session.connection_pid, owner.inventory, inventory)
        PlayerEvents.inventory_changed(owner.character_id)
        PlayerStateCommit.commit(session, %{owner | inventory: inventory})

      {:error, reason} ->
        InventoryManager.notify_add_failed(session.connection_pid, reason)
        session
    end
  end

  defp send_result(session, success),
    do: MessageRouter.send_to(session.connection_pid, %PetCatchResult{success: success})

  @doc "Sends message 669, the refusal to catch a pet on this map."
  @spec send_catch_refusal(%{required(:connection_pid) => pid(), optional(atom()) => term()}) ::
          :ok
  def send_catch_refusal(session) do
    MessageRouter.send_to(session.connection_pid, %ChatNotice{kind: :INFO, text: @catch_refusal})
    :ok
  end

  defp send_count_notice(session) do
    MessageRouter.send_to(session.connection_pid, %SystemNotice{
      id: :SYSTEM_NOTICE_ID_CANT_GET_ITEM_BECAUSE_COUNT
    })
  end
end
