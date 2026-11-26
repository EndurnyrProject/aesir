defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.RogueAgent do
  @moduledoc """
  A Rogue agent coordinates an investigation.

  ## Behavior

  - He recruits the player, directs the investigation, and rewards its completion.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "in_rogue", x: 355, y: 28, dir: 5, sprite: 118, name: "Rogue Agent", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if checkweight(ctx, [{907, 200}]) == 0 do
      ctx
      |> mes("[Guildsman]")
      |> mes("You're carrying too")
      |> mes("much stuff on you.")
      |> mes("Take a load off, put")
      |> mes("your extra stuff in")
      |> mes("Kafra Storage: that's")
      |> mes("what's it's for~")
      |> close()
    else
      investigation(ctx, get_char_var(ctx, :rumour_nd, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp investigation(ctx, 0) do
    progress = get_char_var(ctx, :zdan_edq, 0)

    cond do
      progress == 0 and Rathena.job_id(base_job(ctx)) == Rathena.job_id(:rogue) ->
        ctx
        |> mes("[Guildsman]")
        |> mes("Man, it feels much safer")
        |> mes("hanging out in an alley")
        |> mes("than some crowded joint.")
        |> mes("Us Rogues... I guess you")
        |> mes("can say we got a bit of")
        |> mes("agoraphobia, naturally.")
        |> close()

      progress == 0 ->
        ctx
        |> mes("[Guildsman]")
        |> mes("Hey, I don't think")
        |> mes("you're supposed to be")
        |> mes("here. You better get")
        |> mes("going on your way.")
        |> mes("It's not a threat, just")
        |> mes("a friendly word of advice.")
        |> close()

      progress > 0 and progress < 13 ->
        ctx
        |> mes("[Guildsman]")
        |> mes("Hey, I don't think")
        |> mes("I can help you out.")
        |> mes("You're pretty much")
        |> mes("on your own from here.")
        |> close()

      true ->
        ctx
        |> mes("[Guildsman]")
        |> mes("Huh. I hate clean-up")
        |> mes("duty. It's always better")
        |> mes("to make messes than to")
        |> mes("hang around afterwards.")
        |> close()
    end
  end

  defp investigation(ctx, 1) do
    {ctx, choice} =
      ctx
      |> mes("[Guildsman]")
      |> mes("Yeah, we're investigating")
      |> mes("the strange crimes that are")
      |> mes("going on around the kingdom.")
      |> mes("How'd you know about that?")
      |> next()
      |> select(["I was just...", "Can I help?"])

    case choice do
      1 ->
        ctx
        |> mes("[Guildsman]")
        |> mes("Just what...?")
        |> mes("Speak up, pal.")
        |> close()

      2 ->
        ctx =
          if get_char_var(ctx, :zdan_edq, 0) > 10 do
            ctx
            |> mes("[Guildsman]")
            |> mes("So you wanted to help")
            |> mes("us out? Heck, we could")
            |> mes("use the help, I guess.")
            |> mes("I need you to go on a bit")
            |> mes("of a trip for me, so get")
            |> mes("some provisions ready, yeah?")
            |> set_char_var(:rumour_nd, 2)
          else
            ctx
          end

        close(ctx)

      _ ->
        ctx
    end
  end

  defp investigation(ctx, 2) do
    ctx
    |> mes("[Guildsman]")
    |> mes("You all ready and")
    |> mes("everything? Good.")
    |> mes("Now, I need you to")
    |> mes("deliver some intel to")
    |> mes("the other Rogues for me.")
    |> mes("Think you can do that?")
    |> next()
    |> mes("[Guildsman]")
    |> mes("First, I want you to")
    |> mes("go to Al De Baran.")
    |> mes("Find our guy, and help")
    |> mes("him out any way you can.")
    |> mes("Us Rogues are hard to")
    |> mes("find, but you'll figure it out.")
    |> next()
    |> mes("[Guildsman]")
    |> mes("I know that's probably")
    |> mes("not enough instruction,")
    |> mes("but that's just the first")
    |> mes("step, anyway. Good luck.")
    |> set_char_var(:rumour_nd, 3)
    |> close()
  end

  defp investigation(ctx, 3) do
    ctx
    |> mes("[Guildsman]")
    |> mes("Hey, you gotta get")
    |> mes("goin' to Al De Baran,")
    |> mes("and find one of us Rogues")
    |> mes("working on the investigation.")
    |> mes("I thought you wanted to help?")
    |> next()
    |> mes("[Guildsman]")
    |> mes("Here's a bit of a tip~")
    |> mes("Us Rogue agents usually")
    |> mes("try to hide out in the")
    |> mes("south side of towns.")
    |> mes("Bit of a tradition.")
    |> close()
  end

  defp investigation(ctx, 24) do
    ctx
    |> mes("[Guildsman]")
    |> mes("What's this, a report")
    |> mes("from Al De Baran? 'Kay,")
    |> mes("let me give it a read...")
    |> next()
    |> mes("[Guildsman]")
    |> mes("Huh, okay. Looks like")
    |> mes("your next stop is gonna")
    |> mes("be in Geffen. Look for our")
    |> mes("Geffen agent somewhere in")
    |> mes("the South Geffen area, okay?")
    |> mes("Ah, and take this note too.")
    |> next()
    |> mes("^3355FFYou received")
    |> mes("another folded note.^000000")
    |> set_char_var(:rumour_nd, 25)
    |> close()
  end

  defp investigation(ctx, 25) do
    ctx
    |> mes("[Guildsman]")
    |> mes("Hey, why haven't you")
    |> mes("left for Geffen? Our")
    |> mes("agent oughta be in the")
    |> mes("south side of town.")
    |> mes("It's not far, so don't")
    |> mes("throw a hissy fit.")
    |> close()
  end

  defp investigation(ctx, 21) do
    if get_char_var(ctx, :zdan_edq, 0) > 12 do
      ctx
      |> mes("[Guildsman]")
      |> mes("Finally, the Z Gang")
      |> mes("case is closed. Those")
      |> mes("guys really gave us some")
      |> mes("trouble. Why the hell did")
      |> mes("they stir up so much ruckus")
      |> mes("in the kingdom, anyhow?")
      |> next()
      |> mes("[Guildsman]")
      |> mes("Listen, I wanna thank")
      |> mes("you for pitching in and")
      |> mes("helping out. It's a small")
      |> mes("gift, but maybe you'll")
      |> mes("like it. If not, don't")
      |> mes("lemme know. Got it?")
      |> set_char_var(:rumour_nd, 22)
      |> give_item(644, 1)
      |> close()
    else
      ctx
      |> mes("[Guildsman]")
      |> mes("Listen, I wanna thank")
      |> mes("you for pitching in and")
      |> mes("helping out. It's a small")
      |> mes("gift, but maybe you'll")
      |> mes("like it. If not, don't")
      |> mes("lemme know. Got it?")
      |> set_char_var(:rumour_nd, 22)
      |> give_item(644, 1)
      |> close()
    end
  end

  defp investigation(ctx, 22) do
    ctx
    |> mes("[Guildsman]")
    |> mes("Hey, you were really")
    |> mes("a big help earlier.")
    |> mes("Can we count on you")
    |> mes("again sometime? The")
    |> mes("Rogues can always use")
    |> mes("another friend, you know?")
    |> close()
  end

  defp investigation(ctx, _) do
    ctx
    |> mes("[Guildsman]")
    |> mes("I don't know who you're")
    |> mes("lookin' for, but you")
    |> mes("got the wrong guy.")
    |> mes("Listen, I got work")
    |> mes("to do, so...")
    |> close()
  end
end
