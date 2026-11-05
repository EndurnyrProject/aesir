defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.FlowerVase do
  @moduledoc """
  The flower vase conceals a cryptic message in Kiehl’s rooms.

  ## Behavior

  - Offers inspection after the relevant quest stage.
  - Reveals the message when turned upside-down and resists attempts to break it.

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
        x: 13,
        y: 40,
        dir: 0,
        sprite: 111,
        name: "Flower Vase",
        scope: :shared,
        unique_name: "Flower Vase#kh1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = ctx |> mes("^3355FFYou found") |> mes("a flower vase.^000000")

    if get_char_var(ctx, :KielHyreQuest, 0) < 74 do
      close(ctx)
    else
      inspect_vase(ctx)
    end
  end

  defp inspect_vase(ctx) do
    {ctx, choice} =
      ctx |> next() |> select(["Pick Up Vase", "Break Vase", "Turn Vase Upside-down"])

    case choice do
      1 ->
        ctx |> mes("^3355FFThe vase is empty.^000000") |> close()

      2 ->
        ctx
        |> mes("^3355FFYou can't destroy")
        |> mes("this vase, even by")
        |> mes("striking it with all your")
        |> mes("might. It must have been")
        |> mes("specially manufactured by")
        |> mes("the Rekenber Corporation.^000000")
        |> close()

      3 ->
        read_message(ctx)

      _ ->
        ctx
    end
  end

  defp read_message(ctx) do
    ctx
    |> mes("^3355FFThe following words")
    |> mes("are written at the")
    |> mes("bottom of the vase.^000000")
    |> next()
    |> mes("[Vase Message]")
    |> mes("''The rabbit often")
    |> mes("observes the door")
    |> mes("The night eats the")
    |> mes("pickled orange.''")
    |> close()
  end
end
