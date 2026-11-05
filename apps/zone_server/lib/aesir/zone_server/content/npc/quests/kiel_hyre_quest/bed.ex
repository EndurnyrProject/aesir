defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Bed do
  @moduledoc """
  The abandoned bed offers clues about the former residents.

  ## Behavior

  - Allows examination of the bedsheets or the empty engagement ring box underneath during the investigation.
  - Disturbing the dusty bedsheets removes ten percent HP.

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
        map: "kh_rossi",
        x: 154,
        y: 286,
        dir: 0,
        sprite: 111,
        name: "Bed",
        scope: :shared,
        unique_name: "Bed#khr"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest < 58 -> ctx |> describe_bed() |> close()
      quest < 60 -> search_bed(ctx)
      true -> ctx |> mes("^3355FFThis is a dirty bed.^000000") |> close()
    end
  end

  defp describe_bed(ctx) do
    ctx
    |> mes("^3355FFYou found a well made")
    |> mes("bed that has collected")
    |> mes("a thick layer of dust")
    |> mes("after years of disuse.^000000")
  end

  defp search_bed(ctx) do
    {ctx, choice} =
      ctx |> describe_bed() |> next() |> select(["Check Bedsheets", "Check Under Bed"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYou brush the bed's")
        |> mes("surface with your hand,")
        |> mes("causing a cloud of nasty")
        |> mes("dust to irritate your nose")
        |> mes("and throat. Eww, yucky!^000000")
        |> percent_heal(hp: -10, sp: 0)
        |> close()

      2 ->
        ctx
        |> mes("^3355FFYou search underneath")
        |> mes("the bed, and find an empty")
        |> mes("engagement ring box.^000000")
        |> close()

      _ ->
        ctx
    end
  end
end
