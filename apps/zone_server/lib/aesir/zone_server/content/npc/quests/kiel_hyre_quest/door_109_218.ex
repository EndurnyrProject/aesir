defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Door109218 do
  @moduledoc """
  This locked door prevents entry without the right key.

  ## Behavior

  - Offers an unsuccessful attempt to open the door at the relevant quest stage.

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
        map: "yuno_fild02",
        x: 109,
        y: 218,
        dir: 0,
        sprite: 111,
        name: "Door",
        scope: :shared,
        unique_name: "Door#kh1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("^3355FFThis door is locked.")
      |> mes("If someone inside won't")
      |> mes("open it for you, then you'll")
      |> mes("need the right key to unlock it.")

    if get_char_var(ctx, :KielHyreQuest, 0) == 16 do
      try_door(ctx)
    else
      close(ctx)
    end
  end

  defp try_door(ctx) do
    {ctx, choice} = ctx |> next() |> select(["Open", "Cancel"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYou don't have")
        |> mes("the key that can")
        |> mes("unlock this door.^000000")
        |> close()

      2 ->
        ctx |> mes("......") |> mes(".........") |> mes("............") |> close()

      _ ->
        ctx
    end
  end
end
