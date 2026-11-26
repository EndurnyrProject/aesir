defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.RogueInvestigator do
  @moduledoc """
  A Rogue investigator shares information about the Z Gang's hideout.

  ## Behavior

  - Discusses the hideout with quest participants, charging non-Rogues for information.

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
      %{
        map: "in_rogue",
        x: 366,
        y: 46,
        dir: 3,
        sprite: 828,
        name: "Rogue Investigator",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :diamond_edq, 0) == 22 and
          Rathena.job_id(base_job(ctx)) == Rathena.job_id(:rogue) ->
        {ctx, _} =
          ctx
          |> mes("[Investigator]")
          |> mes("Oh, remember me?")
          |> mes("It's been a long time")
          |> mes("so I can't blame you:")
          |> mes("I was there when you")
          |> mes("first joined our guild!")
          |> mes("So what brings you here?")
          |> next()
          |> select(["Ask About the Z Gang"])

        {ctx, _} =
          ctx
          |> mes("[Investigator]")
          |> mes("Ah, Z Gang, you said?")
          |> next()
          |> mes("[Investigator]")
          |> mes("Oh, yeah, we're investigating")
          |> mes("those guys. We actually found")
          |> mes("their hideout, but then they")
          |> mes("escaped before we could even")
          |> mes("catch them. Wily bastards...")
          |> mes("I think they were tipped off!")
          |> next()
          |> mes("[Investigator]")
          |> mes("A few of our Rogue agents")
          |> mes("are investigating the hideout,")
          |> mes("but I doubt they can find")
          |> mes("anything useful there.")
          |> next()
          |> select(["Where's the hideout?"])

        ctx
        |> mes("[Investigator]")
        |> mes("Well, it's a large")
        |> mes("warehouse over in Comodo.")
        |> mes("You're free to scope out")
        |> mes("the place if you really want.")
        |> mes("But chances are slim that")
        |> mes("you'll find anything at all.")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 22 and
          Rathena.job_id(base_class(ctx)) == Rathena.job_id(:thief) ->
        {ctx, _} =
          ctx
          |> mes("[Investigator]")
          |> mes("Hey, how's it going?")
          |> mes("You ever consider joining")
          |> mes("the Rogues? It'd be a lot")
          |> mes("of fun. You're welcome to")
          |> mes("look around, so feel free")
          |> mes("to ask me any questions.")
          |> next()
          |> select(["Ask About the Z Gang"])

        {ctx, _} =
          ctx
          |> mes("[Investigator]")
          |> mes("Oh, yeah, we're investigating")
          |> mes("those guys. We actually found")
          |> mes("their hideout, but then they")
          |> mes("escaped before we could even")
          |> mes("catch them. Wily bastards...")
          |> mes("I think they were tipped off!")
          |> next()
          |> mes("[Investigator]")
          |> mes("A few of our Rogue agents")
          |> mes("are investigating the hideout,")
          |> mes("but I doubt they can find")
          |> mes("anything useful there.")
          |> next()
          |> select(["Where's the hideout?"])

        {ctx, choice} =
          ctx
          |> mes("[Investigator]")
          |> mes("Well, I'm not sure if")
          |> mes("I can just tell you that")
          |> mes("kind of information. I mean,")
          |> mes("you're not a member of our")
          |> mes("guild... Yet. What can I do?")
          |> next()
          |> mes("[Investigator]")
          |> mes("I got it. I'll just tell my")
          |> mes("boss that you bribed me")
          |> mes("with 10,000 zeny. Not too")
          |> mes("much, is it? We Rogues are")
          |> mes("pretty bad... But not that bad.")
          |> next()
          |> select(["Sounds good!", "Never mind, I'll find it myself..."])

        case choice do
          1 ->
            if zeny(ctx) > 9999 do
              ctx
              |> pay_zeny(10000)
              |> mes("[Investigator]")
              |> mes("Thanks for the money~")
              |> mes("Of course, if you became")
              |> mes("a Rogue, this amount is")
              |> mes("nothing compared to what")
              |> mes("you can gank. ^666666*Ahem*^000000")
              |> next()
              |> mes("[Investigator]")
              |> mes("The Z Gang's old hideout")
              |> mes("is a large warehouse over")
              |> mes("in Comodo. I doubt you'll")
              |> mes("find anything there, but")
              |> mes("you can go check it out. ")
              |> changequest(3115, 3116)
              |> set_char_var(:diamond_edq, 23)
              |> close()
            else
              ctx
              |> mes("[Investigator]")
              |> mes("Aw, what am I gonna")
              |> mes("do if my boss askes to")
              |> mes("see the money? We've got")
              |> mes("to make this bribe authentic!")
              |> close()
            end

          2 ->
            ctx
            |> mes("[Investigator]")
            |> mes("Be my guest, maybe it'll be")
            |> mes("a good learning experience.")
            |> mes("But yeah, come back when")
            |> mes("you think about changing")
            |> mes("your job, okay? Be a Rogue~")
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :diamond_edq, 0) == 22 ->
        {ctx, _} =
          ctx
          |> mes("[Investigator]")
          |> mes("Whoa, what are you doin'")
          |> mes("here? I've got no beef with")
          |> mes("you, but some Rogues, see,")
          |> mes("some Rogues, have got a ")
          |> mes("lot of beef. Uh, what'd you")
          |> mes("want? Not a fight, I hope.")
          |> next()
          |> select(["Ask About the Z Gang"])

        {ctx, _} =
          ctx
          |> mes("[Investigator]")
          |> mes("Those guys have been")
          |> mes("bothering everyone!")
          |> mes("Yeah, I guess you can")
          |> mes("say we're united on this.")
          |> next()
          |> mes("[Investigator]")
          |> mes("Oh, yeah, we're investigating")
          |> mes("those guys. We actually found")
          |> mes("their hideout, but then they")
          |> mes("escaped before we could even")
          |> mes("catch them. Wily bastards...")
          |> mes("I think they were tipped off!")
          |> next()
          |> mes("[Investigator]")
          |> mes("A few of our Rogue agents")
          |> mes("are investigating the hideout,")
          |> mes("but I doubt they can find")
          |> mes("anything useful there.")
          |> next()
          |> select(["Where's the hideout?"])

        {ctx, choice} =
          ctx
          |> mes("[Investigator]")
          |> mes("Uh, I can't just give")
          |> mes("you that information")
          |> mes("if you're not a member")
          |> mes("of our guild. But since")
          |> mes("we're together on this,")
          |> mes("I'll just ask for 10,000 zeny.")
          |> next()
          |> select(["Sounds good!", "Forget it..."])

        case choice do
          1 ->
            if zeny(ctx) > 9999 do
              ctx
              |> pay_zeny(10000)
              |> mes("[Investigator]")
              |> mes("Right on, right on.")
              |> mes("Alright, I didn't charge")
              |> mes("you much since the hideout")
              |> mes("is a large warehouse in")
              |> mes("Comodo where I doubt you'll")
              |> mes("find anything. But who knows? ")
              |> changequest(3115, 3116)
              |> set_char_var(:diamond_edq, 23)
              |> close()
            else
              ctx
              |> mes("[Investigator]")
              |> mes("Hey, this isn't enough")
              |> mes("money. I thought people")
              |> mes("in your job made more")
              |> mes("zeny than this everyday!")
              |> close()
            end

          2 ->
            ctx
            |> mes("[Investigator]")
            |> mes("Alright, but I think")
            |> mes("you'll need a little")
            |> mes("extra help finding that")
            |> mes("place. I mean, Rogues are")
            |> mes("hiding experts, and even")
            |> mes("we had some trouble!")
            |> close()

          _ ->
            ctx
        end

      true ->
        ctx
        |> mes("[Investigator]")
        |> mes("Geez, I'm so sleepy...")
        |> mes("Everyone's out on a mission,")
        |> mes("and I'm stuck here on guard")
        |> mes("duty. When can I see some")
        |> mes("action again? Ugh! Rogues")
        |> mes("hate standing in one place!")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
