defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.QueJob015144 do
  @moduledoc """
  Tao's gate into the patient room and the second master zone of the Morocc job quest.

  ## Behavior

  - Clears `$@moc_mao_room2` on boot and on reset.
  - Lets a player on steps 5 to 9 into the second master zone, a player on steps 22 to 28 into
    the patient room with Rin, and a player on step 21 into the patient room with Rin and Rayan.
    Each opening starts the area timer, warns about the four minutes and warps to its landing
    spot.
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
        y: 44,
        dir: 0,
        sprite: 45,
        name: "que_job01",
        scope: :shared,
        unique_name: "que_job01#room_2",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @map "que_job01"
  @entrance {52, 50}
  @timer " #room2timer"
  @room_var "moc_mao_room2"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: reset_room(ctx)
  def on_event("OnReset", ctx), do: reset_room(ctx)
  def on_event("OnTouch_", ctx), do: admit(ctx)

  defp reset_room(ctx), do: set_server_temp_var(ctx, @room_var, 0)

  defp admit(ctx) do
    case get_char_var(ctx, :mao_morocc2, 0) do
      step when step in 5..9 -> enter_room(ctx, {80, 21}, [])
      step when step in 22..28 -> enter_room(ctx, {144, 57}, ["Rin#moc_room2_2"])
      21 -> enter_room(ctx, {144, 57}, ["Rin#moc_room2_2", "Rayan#moc_room2_2"])
      _step -> patient_room(ctx)
    end
  end

  # The three openings share the sealed-room warning; only the landing spot and the NPCs the
  # room reveals differ between them.
  defp enter_room(ctx, landing, masters) do
    if room_free?(ctx) do
      ctx =
        ctx
        |> set_server_temp_var(@room_var, 1)
        |> donpcevent("#{@timer}::OnEnable")
        |> reveal(masters)
        |> mes("[Tao]")
        |> mes("The room is also sealed with a security magic spell, meow.")
        |> mes("You have ^4d4dff4 minutes^000000")
        |> mes("to finish your quest, meow.")
        |> close()

      warp(ctx, @map, elem(landing, 0), elem(landing, 1))
    else
      occupied(ctx)
    end
  end

  defp reveal(ctx, masters), do: Enum.reduce(masters, ctx, &donpcevent(&2, "#{&1}::OnEnable"))

  defp room_free?(ctx), do: get_server_temp_var(ctx, @room_var, 0) == 0

  defp occupied(ctx) do
    ctx
    |> mes("[Tao]")
    |> mes("We already have a guest inside.")
    |> mes("You can wait or come back later, meow.")
    |> close()
    |> warp(@map, elem(@entrance, 0), elem(@entrance, 1))
  end

  defp patient_room(ctx) do
    ctx
    |> mes("[Tao]")
    |> mes("This is the patient's room, meow.")
    |> mes("Why don't you leave the patient alone to rest?")
    |> close()
    |> warp(@map, elem(@entrance, 0), elem(@entrance, 1))
  end
end
