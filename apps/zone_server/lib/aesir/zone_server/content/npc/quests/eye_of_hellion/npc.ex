defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.Npc do
  @moduledoc """
  The Prontera training dummy that hides the first clue of the Eye of Hellion quest.

  ## Behavior

  - While `HELLIONQ` is 39, points out the gash in the dummy and reads out the
    `Veggie Lady N9 W3 BINGO` clue when the player inspects it, advancing
    `HELLIONQ` to 40.
  - Otherwise describes the dummy left behind when the Swordsman training
    grounds moved to Izlude.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 223,
        y: 82,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#prt_key-1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :HELLIONQ, 0) == 39 do
      inspect_gash(ctx)
    else
      describe_dummy(ctx)
    end
  end

  defp inspect_gash(ctx) do
    {ctx, _choice} =
      ctx
      |> mes("^3355FFIt's a training dummy")
      |> mes("with a gash in its body")
      |> mes("that looks like it was made")
      |> mes("by the thrust of a sharp sword.^000000")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Didn't Clanux mention that he")
      |> mes("found a broken sword around")
      |> mes("here? Maybe this was exactly")
      |> mes("where he found it. Let's see...")
      |> next()
      |> select(["Inspect the dummy's gash"])

    ctx
    |> mes("^3355FFInside of the dummy's body is")
    |> mes("a steel bearing with a roughly")
    |> mes("etched message that reads:^000000")
    |> mes("^4d4dff''Veggie Lady N9 W3 BINGO.''^000000")
    |> set_char_var(:HELLIONQ, 40)
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("What the heck does this")
    |> mes("even mean? A Veggie Lady?")
    |> mes("Does Clanux know anything")
    |> mes("at all about this clue...?")
    |> close()
  end

  defp describe_dummy(ctx) do
    ctx
    |> mes("^3355FFIt's a training dummy")
    |> mes("that was used to hone the")
    |> mes("skills of new Swordmen...")
    |> mes("But the Swordman Training")
    |> mes("Grounds have moved to Izlude.")
    |> close()
  end
end
