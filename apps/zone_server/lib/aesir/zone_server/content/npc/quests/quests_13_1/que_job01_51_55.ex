defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.QueJob015155 do
  @moduledoc """
  Tao's room 1 gate of the Morocc job quest, which lets one authorized player into the timed
  inner room.

  ## Behavior

  - Clears `$@moc_mao_room1` on boot, on reset and on a click.
  - Lets a cursed player (`prt_curse` 24) or a player with an active request into the inner room
    while it is free: starts the area timer, reveals the room's master, warns about the four
    minutes and warps to `que_job01` 11,7.
  - Warps an unauthorized player, or one who finds the room taken, back to the entrance.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_job01",
        x: 51,
        y: 55,
        dir: 0,
        sprite: 45,
        name: "que_job01",
        scope: :shared,
        unique_name: "que_job01#room_1",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @map "que_job01"
  @inner_room {11, 7}
  @entrance {52, 50}
  @timer " #room1timer"
  @room_var "moc_mao_room1"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: reset_room(ctx)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: reset_room(ctx)
  def on_event("OnReset", ctx), do: reset_room(ctx)
  def on_event("OnTouch_", ctx), do: admit(ctx)

  defp reset_room(ctx), do: set_server_temp_var(ctx, @room_var, 0)

  defp admit(ctx) do
    ctx = mes(ctx, "[Tao]")

    cond do
      get_char_var(ctx, :prt_curse, 0) == 24 -> cursed_visitor(ctx)
      get_char_var(ctx, :mao_request, 0) > 0 -> quest_visitor(ctx)
      true -> unauthorized(ctx)
    end
  end

  # The cursed visitor and the quest visitor differ only in which master the room reveals.
  defp cursed_visitor(ctx) do
    if room_free?(ctx) do
      enter(ctx, "Marjana#poison")
    else
      turn_away(ctx)
    end
  end

  defp quest_visitor(ctx) do
    if room_free?(ctx) do
      enter(ctx, "Valdes#moc_master_1")
    else
      turn_away(ctx)
    end
  end

  defp room_free?(ctx), do: get_server_temp_var(ctx, @room_var, 0) == 0

  defp enter(ctx, master) do
    ctx
    |> set_server_temp_var(@room_var, 1)
    |> donpcevent("#{@timer}::OnEnable")
    |> donpcevent("#{master}::OnEnable")
    |> mes("Ah, that place is protected")
    |> mes("by security magic, so you'll")
    |> mes("only have ^4D4DFF4 minutes^000000 to remain")
    |> mes("there. Don't waste time, meow!")
    |> close()
    |> warp(@map, elem(@inner_room, 0), elem(@inner_room, 1))
  end

  defp turn_away(ctx) do
    ctx
    |> mes("Sooo sorry, meow~")
    |> mes("Someone else is already")
    |> mes("inside. Just come back")
    |> mes("again later, meow?")
    |> close()
    |> warp(@map, elem(@entrance, 0), elem(@entrance, 1))
  end

  defp unauthorized(ctx) do
    ctx
    |> mes("Who are you, meow?!")
    |> mes("Only authorized personnel can enter the inner room, meow!")
    |> mes("You are not authorized!")
    |> mes("Get out!")
    |> close()
    |> warp(@map, elem(@entrance, 0), elem(@entrance, 1))
  end
end
