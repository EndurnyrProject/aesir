defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Grer do
  @moduledoc """
  Guides the player through Grer's part of the Brisingamen Seal quest.

  ## Behavior

  - Thanks players who revive the dwarves and advances their quest progress.
  - Hides Grer after conversation and on initialization.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mjo_dun02",
        x: 126,
        y: 34,
        dir: 1,
        sprite: 826,
        name: "Grer",
        scope: :shared,
        unique_name: "Grer#1"
      }
    ]

  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :god_brising, 0)

    cond do
      progress > 47 ->
        ctx
        |> mes("[Grer]")
        |> mes("As we promised,")
        |> mes(
          "Brisingamen will appear in front of human's eyes. But until then, I shall make jewelry of silver. Mwahahaha~"
        )
        |> close2()
        |> hideonnpc("Grer#1")

      progress == 46 ->
        ctx
        |> mes("[Grer]")
        |> mes("My name is Grer.")
        |> mes("I should have been")
        |> mes(
          "the last one to be awakened. Now I see that I haven't mined as much silver as I may need."
        )
        |> next()
        |> mes("[Grer]")
        |> mes(
          "You might think gold would better suit a goddess, but no. Silver is what makes her golden hair more beautiful."
        )
        |> next()
        |> mes("[Grer]")
        |> mes(
          "Now that we're revived, there's a good chance that we may see her again. I don't really mind anything else."
        )
        |> next()
        |> mes("[Grer]")
        |> mes(
          "I want her spirit and scent to fill this world. I don't want Odin or Heimdall to know our plan."
        )
        |> next()
        |> mes("[Grer]")
        |> mes("Now, this doesn't mean")
        |> mes("that I prefer humans over")
        |> mes("gods or giants, but if it's for Freya, I'll do anything.")
        |> next()
        |> mes("[Grer]")
        |> mes("Anyway, now my brothers")
        |> mes(
          "have been revived. For that, I give you my thanks. Someday, you will have the power to challenge the gods."
        )
        |> next()
        |> mes("[Grer]")
        |> mes("Now, I need to")
        |> mes("get back to my work.")
        |> mes("You'll need a silver ornament for the necklace, so I'll continue to mine silver.")
        |> next()
        |> mes("[Grer]")
        |> mes("I will be working")
        |> mes("hard to make the most")
        |> mes("beautiful ornament")
        |> mes("in the world.")
        |> next()
        |> mes("[Grer]")
        |> mes("Okay, you")
        |> mes("may go back now!")
        |> mes("Farewell.")
        |> set_char_var(:god_brising, 47)
        |> close2()
        |> hideonnpc("Grer#1")

      progress == 47 ->
        ctx
        |> mes("[Grer]")
        |> mes("Heh heh...")
        |> mes("Why are you still")
        |> mes("here? Your job is done.")
        |> mes("Now, go back to where")
        |> mes("you came from!")
        |> close2()
        |> hideonnpc("Grer#1")

      true ->
        ctx
        |> mes("[Grer]")
        |> mes("Who the")
        |> mes("hell are you?!")
        |> close2()
        |> hideonnpc("Grer#1")
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx) do
    hideonnpc(ctx, "Grer#1")
  end
end
