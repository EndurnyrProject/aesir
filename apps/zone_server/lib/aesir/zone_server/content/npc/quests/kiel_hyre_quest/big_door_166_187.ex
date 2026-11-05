defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.BigDoor166187 do
  @moduledoc """
  The final large door tests attempts to force and pry it open.

  ## Behavior

  - Summons security monsters until three attempts have been made.
  - Consumes Solid Iron Pieces to widen the gap and enables a timed passage once the door opens.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_kiehl01",
        x: 166,
        y: 187,
        dir: 0,
        sprite: 111,
        name: "Big Door",
        scope: :shared,
        unique_name: "Big Door#BigDoorKHQ5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      get_server_temp_var(ctx, "KHQuestBusy", 0) != 0 or quest_stage < 74 or quest_stage > 106 ->
        describe_closed_door(ctx) |> close()

      quest_stage < 86 ->
        force_door(ctx)

      quest_stage > 84 and quest_stage < 94 ->
        choose_prying_item(ctx)

      quest_stage >= 94 and quest_stage <= 104 ->
        enter_door(ctx)

      true ->
        describe_closed_door(ctx) |> close()
    end
  end

  defp describe_closed_door(ctx) do
    ctx
    |> mes("^3355FFThis large door..")
    |> mes("is closed shut.")
    |> mes("If you listen carefully,")
    |> mes("you can hear the door")
    |> mes("hinges slightly squeak.^000000")
  end

  defp force_door(ctx) do
    {ctx, _choice} =
      ctx
      |> describe_closed_door()
      |> next()
      |> select(["Push Door", "Kick Door", "Shake Door", "Pull Door", "Lift Door"])

    ctx =
      ctx
      |> mes("^3355FFA group of monsters")
      |> mes("suddenly appeared as")
      |> mes("soon as you applied")
      |> mes("pressure to the door.")
      |> mes("This must be some")
      |> mes("kind of security device.^000000")
      |> close()

    ctx =
      ctx
      |> set_temp_var(:KHDoorPushAttempt, get_temp_var(ctx, :KHDoorPushAttempt, 0) + 1)
      |> summon_mob(mob_id: 1739, map: "kh_kiehl01", at: {163, 183})
      |> summon_mob(mob_id: 1740, map: "kh_kiehl01", at: {163, 179})
      |> summon_mob(mob_id: 1739, map: "kh_kiehl01", at: {169, 183})
      |> summon_mob(mob_id: 1740, map: "kh_kiehl01", at: {169, 179})

    if get_temp_var(ctx, :KHDoorPushAttempt, 0) >= 3 do
      set_char_var(ctx, :KielHyreQuest, 86)
    else
      ctx
    end
  end

  defp choose_prying_item(ctx) do
    {ctx, item_choice} =
      ctx
      |> mes("^3355FFYou apply some")
      |> mes("pressure to the door,")
      |> mes("and find that you can")
      |> mes("budge it slightly, but")
      |> mes("you can't fully open it.^000000")
      |> next()
      |> mes("^3355FFIf you wedged something")
      |> mes("into the gap between the")
      |> mes("door and its frame, and")
      |> mes("fully leveraged it, then you")
      |> mes("should be able to open it.^000000")
      |> next()
      |> select([
        "Steel",
        "Rusty Iron Piece",
        "Solid Iron Piece",
        "Iron Piece",
        "Screw",
        "Cancel"
      ])

    case item_choice do
      1 ->
        break_weak_item(ctx, "Steel")

      2 ->
        break_weak_item(ctx, "Rusty Iron Piece")

      3 ->
        pry_with_solid_iron(ctx)

      4 ->
        break_weak_item(ctx, "Iron Piece")

      5 ->
        break_weak_item(ctx, "Screw")

      6 ->
        ctx
        |> mes("^3355FFLet's look for something")
        |> mes("heavy we can use to pry")
        |> mes("open this door.^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp pry_with_solid_iron(ctx) do
    cond do
      count_item(ctx, 7507) < 1 ->
        ctx
        |> mes("^3355FFIf only you had a Solid")
        |> mes("Iron Piece you could use to")
        |> mes("pry open this door.^000000")
        |> close()

      get_char_var(ctx, :KielHyreQuest, 0) < 92 ->
        ctx
        |> mes("^3355FFYou insert one end of")
        |> mes("a Solid Iron Piece into the")
        |> mes("door's gap in a strenuous")
        |> mes("effort to pry the door open")
        |> mes("The gap widens a little bit,")
        |> mes("but you break one of your")
        |> mes("Solid Iron Pieces.^000000")
        |> delitem(7507, 1)
        |> set_char_var(:KielHyreQuest, get_char_var(ctx, :KielHyreQuest, 0) + 2)
        |> close()

      get_char_var(ctx, :KielHyreQuest, 0) == 92 ->
        ctx
        |> mes("^3355FFWith a mighty heave,")
        |> mes("you pry a Solid Iron")
        |> mes("Piece into the door jamb,")
        |> mes("and fling the door wide open")
        |> mes("Unable the withstand the")
        |> mes("awesome force, this Solid")
        |> mes("Iron Piece shatters into dust.^000000")
        |> delitem(7507, 1)
        |> set_char_var(:KielHyreQuest, 94)
        |> close()

      true ->
        break_weak_item(ctx, "Iron Piece")
    end
  end

  defp break_weak_item(ctx, item_name) do
    ctx = set_local(ctx, :"KHPryingItem$", item_name)

    ctx
    |> mes("^3355FFThis #{get_local(ctx, :"KHPryingItem$", "")} is far")
    |> mes("to weak for what you're using it for")
    |> mes("and breaks.^000000")
    |> close()
  end

  defp enter_door(ctx) do
    if get_npc_var(ctx, "KHDoor5Opened", 0) == 0 do
      offer_entry(ctx)
    else
      ctx |> mes("^3355FFThe door is open.^000000") |> close()
    end
  end

  defp offer_entry(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThe large door")
      |> mes("is wide open, and.")
      |> mes("you may now enter.^000000")
      |> next()
      |> select(["Yes", "No"])

    case choice do
      1 ->
        ctx
        |> close()
        |> donpcevent("Big_Door_5_Warp::OnEnable")
        |> enablenpc("Big_Door_5_Warp")
        |> set_npc_var("KHDoor5Opened", 1)

      2 ->
        ctx
        |> mes("^3355FFWho knows what is on the")
        |> mes("other side of this door. Let's")
        |> mes("think about it before barging in..^000000")
        |> close()

      _ ->
        ctx
    end
  end
end
