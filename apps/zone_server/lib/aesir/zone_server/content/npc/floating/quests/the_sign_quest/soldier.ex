defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.TheSignQuest.Soldier do
  @moduledoc """
  Maruin guards the castle and receives a birthday gift from his sister.

  ## Behavior

  - Accepts the gift during the quest and restores the visitor’s health and SP.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "Soldier", scope: :shared, unique_name: "Soldier#s11_"},
      %{
        map: "prt_cas",
        x: 87,
        y: 214,
        dir: 8,
        sprite: 105,
        name: "Soldier",
        scope: :renewal,
        unique_name: "Soldier#s11"
      },
      %{
        map: "prt_castle",
        x: 107,
        y: 58,
        dir: 5,
        sprite: 105,
        name: "Soldier",
        scope: :pre_renewal,
        unique_name: "Soldier#s11"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Maruin]")
    quest = get_char_var(ctx, :sign_q, 0)

    cond do
      quest < 49 or quest in [97, 98] -> greeting(ctx)
      quest == 49 and count_item(ctx, 7044) < 1 and count_item(ctx, 7183) < 1 -> greeting(ctx)
      quest == 49 -> receive_gift(ctx)
      true -> thank_visitor(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greeting(ctx) do
    ctx
    |> mes("Welcome to")
    |> mes("Prontera Castle.")
    |> mes("Please be careful")
    |> mes("and avoid getting lost.")
    |> next()
    |> mes("[Maruin]")
    |> mes("Oh man...")
    |> mes("I'm so tired~!")
    |> mes("Enervated, even~")
    |> mes("If I only had some")
    |> mes("kind of refreshment...")
    |> close()
  end

  defp receive_gift(ctx) do
    {ctx, _} =
      ctx
      |> mes("Welcome to")
      |> mes("Prontera Castle.")
      |> mes("Please be careful")
      |> mes("and avoid getting los--")
      |> next()
      |> mes("[Maruin]")
      |> mes("What's that?")
      |> mes("You're here for")
      |> mes("my sister? Um, did")
      |> mes("something happen...?")
      |> next()
      |> select(["Oh no, she sent you a birthday gift."])

    ctx
    |> mes("[Maruin]")
    |> mes("Birthday...?")
    |> mes("What are you sm--")
    |> mes("OH. It is my birthday.")
    |> mes("Ha! I completely forgot!")
    |> next()
    |> mes("[Maruin]")
    |> mes("Thanks for coming")
    |> mes("all the way out here")
    |> mes("to deliver my present!")
    |> mes("Wow, I wonder what she")
    |> mes("got for me this year?")
    |> next()
    |> emotion(:surprise)
    |> mes("[Maruin]")
    |> mes("Th-this is--!")
    |> mes("Oh. Snap. That's right.")
    |> mes("She's been worried about")
    |> mes("me being tired lately. But")
    |> mes("does she even know what")
    |> mes("Vigorgra is supposed to...?")
    |> next()
    |> mes("[Maruin]")
    |> mes("Never mind. It's the")
    |> mes("thought that counts.")
    |> mes("But for the record, it's")
    |> mes("not like I need this stuff.")
    |> mes("I mean, I have, you know,")
    |> mes("a girlfr--you know what I mean.")
    |> next()
    |> mes("[Maruin]")
    |> mes("I'd like to pay you")
    |> mes("back, but since I'm")
    |> mes("on duty, all I can do")
    |> mes("is replenish your health.")
    |> mes("I'm not really supposed to,")
    |> mes("but no one will say anything.")
    |> delitem(7044, 1)
    |> delitem(7183, 1)
    |> set_char_var(:sign_q, 50)
    |> percent_heal(hp: 100, sp: 100)
    |> next()
    |> mes("[Maruin]")
    |> mes("Well, thanks for")
    |> mes("the letter and the")
    |> mes("male supplement, I guess.")
    |> mes("I'll send a message to my")
    |> mes("sister. Good luck on your")
    |> mes("travels, alright?")
    |> close()
  end

  defp thank_visitor(ctx) do
    ctx =
      ctx
      |> mes("Oh hey, how's")
      |> mes("it going? Thanks")
      |> mes("again for helping")
      |> mes("out my sister, we")
      |> mes("really appreciate it.")

    ctx =
      if sex(ctx) == 1 and Enum.random(1..5) == 5 do
        ctx
        |> next()
        |> mes("[Maruin]")
        |> mes("Oh...")
        |> mes("And just between you")
        |> mes("and me, that Vigorgra")
        |> mes("really came in handy!")
        |> mes("That stuff's amazing!")
      else
        ctx
      end

    close(ctx)
  end
end
