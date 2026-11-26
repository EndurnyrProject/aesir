defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Manson do
  @moduledoc """
  Manson is a senior servant who knows about Phobe's disappearance.

  ## Behavior

  - Describes Phobe's last errand and sends the adventurer to Jenny.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_in01",
        x: 372,
        y: 200,
        dir: 3,
        sprite: 929,
        name: "Manson",
        scope: :shared,
        unique_name: "Manson#ra_in01"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :lost_boy, 0) < 1 -> greeting(ctx)
      get_char_var(ctx, :lost_boy, 0) == 1 -> describe_work(ctx)
      get_char_var(ctx, :lost_boy, 0) == 2 -> discuss_phobe(ctx)
      get_char_var(ctx, :lost_boy, 0) == 3 -> refer_to_jenny(ctx)
      true -> busy(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Manson]")
    |> mes("I am Manson, one of the")
    |> mes("many servants working here")
    |> mes("in Sir Zhed's mansion. Er,")
    |> mes("would you be more careful")
    |> mes("walking around here? I hate")
    |> mes("cleaning up after visitors.")
    |> close()
  end

  defp describe_work(ctx) do
    ctx
    |> mes("[Manson]")
    |> mes("You know, considering")
    |> mes("that natives like me are")
    |> mes("looked down upon and")
    |> mes("are kinda of lower class,")
    |> mes("I'm really lucky to work for")
    |> mes("Sir Zhed here in the mansion.")
    |> close()
  end

  defp discuss_phobe(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Excuse me, but do you")
    |> mes("know a man named Phobe?")
    |> mes("He's gone missing, so I've")
    |> mes("been hired to look for him.")
    |> next()
    |> mes("[Manson]")
    |> mes("Ah, so you're the one")
    |> mes("that Vincent hired, huh?")
    |> mes("That's good, that's good.")
    |> mes("I'm pretty sure Phobe is")
    |> mes("hiding somewhere and")
    |> mes("just goofing around.")
    |> next()
    |> mes("[Manson]")
    |> mes("I'm sure he can take care")
    |> mes("of himself, so we won't have")
    |> mes("to worry too much. Let's see,")
    |> mes("he asked me if I had any")
    |> mes("errands to for him to do,")
    |> mes("so I sent him to the market.")
    |> next()
    |> mes("[Manson]")
    |> mes("That's the last time I saw")
    |> mes("him. I guess he's using the")
    |> mes("money I gave him to feed himself")
    |> mes("while he's run away. He's young,")
    |> mes("so I can't really blame him.")
    |> mes("We've all done crazy things~")
    |> next()
    |> mes("[Manson]")
    |> mes("Ah, our gardener Jenny")
    |> mes("was the one that introduced")
    |> mes("me to him. She's worked for")
    |> mes("Sir Zhed for a long time, and")
    |> mes("she loves kids. I guess she's")
    |> mes("got a soft spot for Phobe.")
    |> next()
    |> mes("[Manson]")
    |> mes("No one knows who his")
    |> mes("parents are, so I guess")
    |> mes("he's an orphan. That's")
    |> mes("probably why she has him.")
    |> mes("working with us in the mansion.")
    |> next()
    |> mes("[Manson]")
    |> mes("Jenny has done a lot for")
    |> mes("that boy. We skipped our")
    |> mes("usual employment process")
    |> mes("just for her, you know? And")
    |> mes("now Jenny and even Vincent")
    |> mes("are worried about him missing.")
    |> next()
    |> mes("[Manson]")
    |> mes("You know, if you want to")
    |> mes("know more about that kid,")
    |> mes("you should talk to Jenny.")
    |> mes("She's working in the garden")
    |> mes("now, and she'd appreciate")
    |> mes("your help in finding Phobe.")
    |> set_char_var(:lost_boy, 3)
    |> changequest(8090, 8091)
    |> close()
  end

  defp refer_to_jenny(ctx) do
    ctx
    |> mes("[Manson]")
    |> mes("You know, if you want to")
    |> mes("know more about that kid,")
    |> mes("you should talk to Jenny.")
    |> mes("She's working in the garden")
    |> mes("now, and she'd appreciate")
    |> mes("your help in finding Phobe.")
    |> close()
  end

  defp busy(ctx) do
    ctx
    |> mes("[Manson]")
    |> mes("Nuts, there's so much")
    |> mes("work to do! I never seem")
    |> mes("to get it all done until")
    |> mes("the very end of the day.")
    |> mes("Ah well, it's a living.")
    |> close()
  end
end
