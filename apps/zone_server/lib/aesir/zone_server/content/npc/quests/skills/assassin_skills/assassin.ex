defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AssassinSkills.Assassin do
  @moduledoc """
  Killtin, the Assassin Guild instructor who teaches Venom Knife.

  ## Behavior

  - Introduces the guild's two new skills to Assassins and explains each on request.
  - Insists on teaching Venom Knife until the player agrees, then grants the skill and starts
    the Sonic Acceleration quest.
  - Re-teaches Venom Knife to Assassins who completed the quest but lost the skill.
  - Thieves are told to get stronger; other players are sent away.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - DracoRPG
    - L0ne_W0lf
    - 2Spiritual Kid (bug report)

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_moc_16",
        x: 14,
        y: 27,
        dir: 5,
        sprite: 884,
        name: "Assassin",
        scope: :shared,
        unique_name: "Assassin#realman"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      assassin?(ctx) and get_char_var(ctx, :ASSN_SK2, 0) == 1 ->
        if getskilllv(ctx, 1004) == 0, do: reteach_venom_knife(ctx), else: check_in(ctx)

      get_char_var(ctx, :ASSN_SK2, 0) == 1 and get_char_var(ctx, :ASSN_SK, 0) == 7 ->
        ctx
        |> mes("[Killtin]")
        |> mes("So you've learned all of")
        |> mes("the specialized Assassin")
        |> mes("skills, eh? Don't let yourself")
        |> mes("become overconfident. Strive")
        |> mes("for even greater strength for")
        |> mes("the Assassin Guild's honor.")
        |> close()

      get_char_var(ctx, :ASSN_SK2, 0) == 1 ->
        check_in(ctx)

      assassin?(ctx) ->
        introduce_new_skills(ctx)

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:thief) ->
        ctx
        |> mes("[Killtin]")
        |> mes("A Thief...? Huh.")
        |> mes("That's a respectable")
        |> mes("job. But listen, if you")
        |> mes("want me to be able to")
        |> mes("teach you anything, you'll")
        |> mes("need to get stronger first.")
        |> close()

      true ->
        ctx
        |> mes("[Assassin]")
        |> mes("...............................")
        |> mes("Just keep moving.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp assassin?(ctx), do: Rathena.job_id(base_job(ctx)) == Rathena.job_id(:assassin)

  defp check_in(ctx) do
    ctx
    |> mes("[Killtin]")
    |> mes("So how has that")
    |> mes("^990099Venom Knife^000000 skill")
    |> mes("been working for you?")
    |> mes("Be careful, and make sure")
    |> mes("that your victims always")
    |> mes("deserve what you give them!")
    |> close()
  end

  defp reteach_venom_knife(ctx) do
    ctx
    |> mes("[Killtin]")
    |> mes("Ah yes, that's why you")
    |> mes("look so familiar. You're")
    |> mes("of those to whom I've taught")
    |> mes("the ^990099Venom Knife^000000 skill. So, what")
    |> mes("brings you to me this time?")
    |> next()
    |> mes("[Killtin]")
    |> mes("What's that...?!")
    |> mes("You want me to teach")
    |> mes("it to you once again?")
    |> mes("It's a shame you've forgotten,")
    |> mes("but I suppose it can't be helped. Alright, alright, I'll teach you.")
    |> next()
    |> demonstrate_venom_knife()
    |> mes("[Killtin]")
    |> mes("Good... Very good...")
    |> mes("Perfect form. Yes...")
    |> mes("Hmm. Are you sure that")
    |> mes("you forgot how to do this")
    |> mes("skill? I suppose that all you")
    |> mes("needed was a quick refresher.")
    |> specialeffect2(:invenom)
    |> next()
    |> mes("[Killtin]")
    |> mes("Alright, I think it's")
    |> mes("safe to say that you've")
    |> mes("mastered the Venom Knife")
    |> mes("skill. Leave me now, and")
    |> mes("always fight for the honor")
    |> mes("of the Assassin Guild!")
    |> skill(1004, 1, :permanent)
    |> close()
  end

  defp introduce_new_skills(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Killtin]")
      |> mes("Hm? Ah, you're definitely")
      |> mes("a member of the Assassin")
      |> mes("Guild. Great, you've come")
      |> mes("just at the right time.")
      |> next()
      |> mes("[Killtin]")
      |> mes("Our guildmaster recently")
      |> mes("succeeded in developing two")
      |> mes("new skills for Assassins. I've")
      |> mes("been charged with the task of")
      |> mes("teaching these new skills to")
      |> mes("all the members of our guild.")
      |> next()
      |> select(["New skills?"])

    ctx = mes(ctx, "[Killtin]")

    ctx
    |> mes("That's right, #{char_name(ctx, 0)}.")
    |> mes("The first skill specifically")
    |> mes("enhances the Sonic Blow")
    |> mes("skill, and the second skill")
    |> mes("is a long range attack that's")
    |> mes("named ''^990099Venom Knife^000000.''")
    |> next()
    |> mes("[Killtin]")
    |> mes("If you have any questions,")
    |> mes("feel free to ask me about")
    |> mes("any of these new skills. It's")
    |> mes("my job to teach you as much")
    |> mes("as I can about them.")
    |> next()
    |> skills_menu()
  end

  defp skills_menu(ctx) do
    {ctx, choice} =
      select(ctx, [
        "^0000FFSonic Blow Enhancement^000000",
        "^990099Venom Knife^000000",
        "Continue Conversation"
      ])

    case choice do
      1 ->
        ctx |> explain_sonic_acceleration() |> skills_menu()

      2 ->
        ctx |> explain_venom_knife() |> skills_menu()

      3 ->
        ctx
        |> mes("[Killtin]")
        |> mes("Now, if you like, I can")
        |> mes("teach you the ^009900Venom Knife^000000")
        |> mes("skill right now. It won't take")
        |> mes("that much time, so what do")
        |> mes("you say? You ready to learn?")
        |> next()
        |> insist_on_teaching()

      _ ->
        skills_menu(ctx)
    end
  end

  defp explain_sonic_acceleration(ctx) do
    ctx
    |> mes("[Killtin]")
    |> mes("If you've been an Assassin")
    |> mes("for a while, then you must")
    |> mes("be familiar with the Sonic")
    |> mes("Blow skill, which inflicts 8")
    |> mes("powerful strikes at an enemy")
    |> mes("in one blindingly fast attack.")
    |> next()
    |> mes("[Killtin]")
    |> mes("However, due to the speed")
    |> mes("involved in that skill, Sonic")
    |> mes("Blow isn't as accurate as it")
    |> mes("can be. After years of testing")
    |> mes("and research, our guildmaster")
    |> mes("developed a way to fix this.")
    |> next()
    |> mes("[Killtin]")
    |> mes("He created a new skill")
    |> mes("named ''Sonic Acceleration''")
    |> mes("that Assassins can cast on")
    |> mes("themselves in order to quickly")
    |> mes("detect and accurately strike")
    |> mes("the target's fatal points.")
    |> next()
    |> mes("[Killtin]")
    |> mes("In effect, Sonic Acceleration")
    |> mes("roughly doubles the damage")
    |> mes("that you can inflict with the")
    |> mes("Sonic Blow. If you use Sonic")
    |> mes("Blow pretty often, then this")
    |> mes("skill will be pretty useful.")
    |> next()
    |> mes("[Killtin]")
    |> mes("I suggest that you learn")
    |> mes("the Venom Knife skill from")
    |> mes("me first. Then, you can talk")
    |> mes("to Esmille, the beautiful")
    |> mes("Assassin Cross right next to me, to learn Sonic Acceleration.")
    |> next()
  end

  defp explain_venom_knife(ctx) do
    ctx
    |> mes("[Killtin]")
    |> mes("As you may well know, our")
    |> mes("job isn't really known for its")
    |> mes("long range attacks. Sure, we")
    |> mes("can use Bows, and we've got")
    |> mes("a few long distance skills, but")
    |> mes("their uses are kind of limited.")
    |> next()
    |> mes("[Killtin]")
    |> mes("This Venom Knife skill was")
    |> mes("developed with this weakness")
    |> mes("in long range attacking in mind. Basically, we use the Envenom")
    |> mes("skill on a knife and throw it at a distant enemy to poison them.")
    |> next()
  end

  defp insist_on_teaching(ctx) do
    {ctx, choice} = select(ctx, ["Learn Venom Knife", "I d-don't wanna learn!"])

    if choice == 1 do
      teach_venom_knife(ctx)
    else
      ctx |> refuse_refusal() |> insist_on_teaching()
    end
  end

  defp refuse_refusal(ctx) do
    if get_local(ctx, :teach, 0) == 1 do
      ctx
      |> mes("[Killtin]")
      |> mes("Y-you don't want to")
      |> mes("learn? Tough! It's my")
      |> mes("job to teach this Venom")
      |> mes("Knife skill to every member")
      |> mes("of the Assassin Guild! You're^FFFFFFaaaaa^000000 not leaving until I tell you to!")
      |> next()
    else
      ctx
      |> mes("[Killtin]")
      |> mes("You can't refuse an")
      |> mes("order from our guildmaster...")
      |> mes("Like it or not, this skill will")
      |> mes("make you a better Assassin.")
      |> mes("Trust me on this and just agree")
      |> mes("to learn the skill, will you?")
      |> next()
    end
  end

  defp teach_venom_knife(ctx) do
    ctx
    |> demonstrate_venom_knife()
    |> mes("[Killtin]")
    |> mes("Hey, that's pretty good.")
    |> mes("You're catching on really")
    |> mes("quick. Heh heh, but still,")
    |> mes("I guess I can take a little")
    |> mes("bit of credit for my excellent")
    |> mes("instruction. Ah, very nice.")
    |> next()
    |> specialeffect2(:invenom)
    |> next()
    |> mes("[Killtin]")
    |> mes("Alright, you may need")
    |> mes("to practice a bit more")
    |> mes("of this skill, but for the most")
    |> mes("part, you can use Venom")
    |> mes("Knife pretty easily in battle.")
    |> set_char_var(:ASSN_SK2, 1)
    |> set_char_var(:ASSN_SK, 1)
    |> skill(1004, 1, :permanent)
    |> next()
    |> mes("[Killtin]")
    |> mes("Well, that's all I can")
    |> mes("teach you. Use this skill")
    |> mes("expertly, and bring woe to")
    |> mes("your enemies for the honor")
    |> mes("of the Assassin Guild!")
    |> close()
  end

  defp demonstrate_venom_knife(ctx) do
    ctx
    |> mes("[Killtin]")
    |> mes("First, you need to equip")
    |> mes("a Knife class weapon, and")
    |> mes("then cast Envenom on your")
    |> mes("knife. Throwing the blade?")
    |> mes("That's all in the wrist. Now,")
    |> mes("watch me closely and take note.")
    |> next()
    |> mes("[Killtin]")
    |> mes("You see? Having")
    |> mes("good form is essential")
    |> mes("to performing flawless")
    |> mes("technique. Always basics")
    |> mes("before the specifics. Now,")
    |> mes("why don't you give it a try?")
    |> specialeffect(:invenom)
    |> next()
  end
end
