defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Bartender do
  @moduledoc """
  Explains the ingredient shortages affecting a Prontera tavern's special dishes.

  ## Behavior

  - Describes the monsters whose ingredients are needed for two menu specialties.
  - Repeats the topic menu until the visitor cancels.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 180,
        y: 20,
        dir: 2,
        sprite: 61,
        name: "Bartender",
        scope: :shared,
        unique_name: "Bartender#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Bartender]")
    |> mes("Sigh...as more and more people coming into Prontera,")
    |> mes("better and better my business has become nowadays. But...")
    |> mes("Well, I am having a hard time to keep a good stock of food ingredients.")
    |> next()
    |> mes("[Bartender]")
    |> mes(
      "As you see, the numbers of the monsters outside of town has been greatly increased and they have caused trouble to my suppliers to deliver the goods at a right time."
    )
    |> mes(
      "I cannot make my ultra nice menus with common ingredients because they are super special!"
    )
    |> next()
    |> mes("[Bartender]")
    |> mes(
      "So I have been contacting super heavy champion hunters for fresh and special ingredients."
    )
    |> mes("But the demand has exceeded the supply in these days.")
    |> next()
    |> mes("[Bartender]")
    |> mes(
      "I can't keep my business busy without my special menu 'Crunch Crunch Sour' and 'Savory Yum Yum'...*Sigh*"
    )
    |> choose_topic()
  end

  defp choose_topic(ctx) do
    {ctx, choice} =
      ctx |> next() |> select(["'Crunch Crunch Sour'?", "'Savory Yum Yum'?", "Cancel."])

    case choice do
      1 -> ctx |> explain_crunch_crunch_sour() |> choose_topic()
      2 -> ctx |> explain_savory_yum_yum() |> choose_topic()
      3 -> ctx |> mes("[Bartender]") |> mes("Take care of yourself~.") |> close()
      _ -> choose_topic(ctx)
    end
  end

  defp explain_crunch_crunch_sour(ctx) do
    ctx
    |> mes("[Bartender]")
    |> mes(
      "The basic ingredients of my Crunch Crunch Sour are the ants roaming inside the Ant Hell in the desert."
    )
    |> mes(
      "Rumor has it that the numbers of the ants have been greatly increased and they have become more violent, so that no one wants to get in the place."
    )
    |> next()
    |> mes("[Bartender]")
    |> mes("*Sigh*...I am afraid that my business days are numbered now.")
  end

  defp explain_savory_yum_yum(ctx) do
    ctx
    |> mes("[Bartender]")
    |> mes(
      "Savory Yum Yum's basic ingredients are the grasshoppers romping in a place over the west forest. Yeah, it is the best selling menu ever."
    )
    |> mes(
      "Rumor has it that they have become very violent and Bees have built their habitat in the place, so that no one wants to get in there."
    )
    |> next()
    |> mes("[Bartender]")
    |> mes("*Sigh*...I am afraid that my business days are numbered now.")
  end
end
