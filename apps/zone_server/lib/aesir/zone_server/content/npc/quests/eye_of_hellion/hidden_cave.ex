defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.HiddenCave do
  @moduledoc """
  A hidden cave holds Tyus's final message and the entrance to his chamber.

  ## Behavior

  - At quest step 68, offers to open the cave and warp inside after reading the message.
  - Signals a nearby tablet when the player enters its area.

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
        map: "gef_fild09",
        x: 296,
        y: 59,
        dir: 0,
        sprite: 111,
        name: "Hidden Cave",
        scope: :shared,
        unique_name: "Hidden Cave#hellion",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :HELLIONQ, 0) == 68 and count_item(ctx, 7332) > 0 do
      ctx
      |> specialeffect2(:heal2)
      |> specialeffect(:heal2)
      |> mes("^3355FFThe tablet in your")
      |> mes("hands begins to shine")
      |> mes("with light, responding")
      |> mes("to something in the area.^000000")
      |> close()
    else
      ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :HELLIONQ, 0) == 68 do
      {ctx, choice} =
        ctx
        |> mes("^3355FFAmongst the wild bushes")
        |> mes("and overgrown grass, you")
        |> mes("see a large rock slab that")
        |> mes("resembles a door. As you")
        |> mes("come closer, you can see a")
        |> mes("groove on the rock's surface.^000000")
        |> next()
        |> select(["Insert the Tablet.", "Ignore."])

      if choice == 1 do
        enter_cave(ctx)
      else
        ctx |> mes("^3355FFYou do nothing.") |> mes("And nothing happens.^000000") |> close()
      end
    else
      ctx
    end
  end

  defp enter_cave(ctx) do
    ctx
    |> mes("^3355FFYou insert the tablet into")
    |> mes("the rock's groove and the")
    |> mes("Hellion's gem begins to hum")
    |> mes("and glow. The rock slides open,")
    |> mes("revealing an engraved message")
    |> mes("on the ground for you to read.^000000")
    |> next()
    |> mes("^4D4DFF''To you who have found this")
    |> mes("place, I reveal the truth about")
    |> mes("the Hellion Revenant. It was")
    |> mes("never a devil, like we believed, but a human being, slowly")
    |> mes("corrupted by the darkness")
    |> mes("of the Hellion's gem.''^000000")
    |> next()
    |> mes("^4D4DFF''I learned this horrible")
    |> mes("truth too late. Already,")
    |> mes("I can feel the darkness")
    |> mes("welling up within me.")
    |> mes("It is all I can do to trap")
    |> mes("myself in this chamber")
    |> mes("before I lose all reason.''^000000")
    |> next()
    |> mes("^4D4DFF''I failed and it's too")
    |> mes("late for me, but I hope")
    |> mes("someone in the future")
    |> mes("can seal the Hellion gem's")
    |> mes("dark power. And I hope that")
    |> mes("someone will grant me the")
    |> mes("sweet release I crave...''^000000")
    |> next()
    |> mes("^4D4DFF''Brave hero, I beg of")
    |> mes("you. Please kill me and")
    |> mes("bring salvation to my soul.")
    |> mes("Please release me so that")
    |> mes("I can finally join my friends.")
    |> mes("^FFFFFF_^000000")
    |> mes("^FFFFFFOOOOOOOOOOO^4D4DFF-Tyus''^000000")
    |> close()
    |> warp("gef_dun03", 140, 119)
  end
end
