defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.BardSkills.SpitefulLookingBard do
  @moduledoc """
  Riott, a spiteful Bard in the Morocc pub, who teaches the Pang Voice skill.

  ## Behavior

  - Laughs at visitors and notices the Black or Silver Bard Seal from the Geffen Bard quest.
  - With a seal, a Bard sent by the Timid Young Man watches Riott scramble two drunks' minds and
    is asked to fetch 5 Eggs from Yhelle the hen in Niflheim.
  - Teaches Pang Voice for the 5 Eggs; a Bard with fewer eggs hands them over and must bring a
    Munak Doll instead.
  - Reteaches Pang Voice to a Minstrel who lost it after transcending.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - L0ne_W0lf
    - DracoRPG

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
    quests/skills/bard_skills.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc_in",
        x: 169,
        y: 72,
        dir: 7,
        sprite: 741,
        name: "Spiteful-Looking Bard",
        scope: :shared,
        unique_name: "Spiteful-Looking Bard#bs",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @pang_voice 1010
  @egg 574
  @munak_doll 7277

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    emotion(ctx, :kik)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:bard),
      do: talk_to_bard(ctx),
      else: talk_to_outsider(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp player_says(ctx), do: mes(ctx, "[#{char_name(ctx, 0)}]")

  defp talk_to_bard(ctx) do
    progress = get_char_var(ctx, :qskill_bard, 0)

    cond do
      Rathena.job_id(class(ctx)) == Rathena.job_id(:clown) and progress == 9 ->
        if getskilllv(ctx, @pang_voice) != 0, do: making_good_use(ctx), else: offer_relearn(ctx)

      progress > 8 ->
        making_good_use(ctx)

      progress == 8 ->
        if count_item(ctx, @munak_doll) > 0,
          do: accept_munak_doll(ctx),
          else: await_munak_doll(ctx)

      progress == 7 ->
        if count_item(ctx, @egg) > 4, do: accept_eggs(ctx), else: too_few_eggs(ctx)

      progress > 1 and progress < 7 ->
        egg_trouble(ctx)

      true ->
        ctx |> laugh() |> bard_seal_check()
    end
  end

  defp making_good_use(ctx) do
    ctx
    |> mes("[Riott]")
    |> mes("Geh heh heh~")
    |> mes("Been making good use of")
    |> mes("what I taught you? Just be")
    |> mes("careful and don't use that skill recklessly. Otherwise, people")
    |> mes("will hate you as they hate me.")
    |> next()
    |> mes("[Riott]")
    |> mes("Your enemies, and the")
    |> mes("occasional drunkard, on")
    |> mes("the other hand, are different")
    |> mes("matters entirely! Bwah hah hah!")
    |> close()
  end

  defp offer_relearn(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Riott]")
      |> mes("Impossible! You forgot")
      |> mes("everything I've taught you?")
      |> mes("How can that be? Oh well, it's")
      |> mes("no trouble for me to teach that")
      |> mes("to you again if you'd like.")
      |> next()
      |> select(["No, thanks.", "Thanks, I'd appreciate that."])

    if choice == 1 do
      ctx
      |> mes("[Riott]")
      |> mes("What...?")
      |> mes("You really don't")
      |> mes("want to learn it?")
      |> mes("I assure you there's")
      |> mes("no strings attached.")
      |> mes("If you change your mind...")
      |> close()
    else
      ctx
      |> mes("[Riott]")
      |> mes("First, you must stare")
      |> mes("fiercely into the eyes of")
      |> mes("your target, and focus on")
      |> mes("thoughts of dominance. This")
      |> mes("is the basis for mesmerization. Now listen to this incantation...")
      |> next()
      |> mes("[Riott]")
      |> mes("Uuuummm Baaalaaaa")
      |> mes("Uuuummmm Baaalaaa~")
      |> mes("Kkkkuuurrirrreeee")
      |> mes("Kkkkuuurrirrreeee")
      |> mes("Oooumm guandlejdl")
      |> mes("Woooo Ei ei ei ei......")
      |> specialeffect(:talk_frostjoke)
      |> next()
      |> mes("[Riott]")
      |> mes("Pang's Voice is used to")
      |> mes("confuse people and disrupt")
      |> mes("control of their bodies. It's not a fatal skill, but it is effective")
      |> mes("in mentally upsetting your enemy. Make very wise use of this skill.")
      |> skill(@pang_voice, 1, :permanent)
      |> close()
    end
  end

  defp accept_munak_doll(ctx) do
    ctx
    |> mes("[Riott]")
    |> mes("Ah, you've brought me")
    |> mes("a Munak Doll made by")
    |> mes("Yao Jun, just like you said")
    |> mes("you would. Ah yes, this is her")
    |> mes("craftsmanship, impeccable")
    |> mes("as always. You've done well~")
    |> next()
    |> teach_pang_voice(@munak_doll, 1)
  end

  defp await_munak_doll(ctx) do
    ctx
    |> mes("[Riott]")
    |> mes("Hmpf. Weren't able")
    |> mes("to find me a Munak Doll")
    |> mes("yet? Well, don't worry, I'm")
    |> mes("a patient man. Just try to get")
    |> mes("one for me as soon as you can.")
    |> close()
  end

  defp accept_eggs(ctx) do
    ctx
    |> mes("[Riott]")
    |> mes("Ah, you've brought me")
    |> mes("some fresh eggs laid by")
    |> mes("Yhelle, just like I asked.")
    |> mes("I'm sure it was dangerous")
    |> mes("going to Niflheim, but the flavor of these eggs is worth it.")
    |> next()
    |> next()
    |> teach_pang_voice(@egg, 5)
  end

  defp teach_pang_voice(ctx, payment, amount) do
    ctx
    |> mes("[Riott]")
    |> mes("To fulfill my part of this")
    |> mes("bargain, I shall now teach")
    |> mes("you my special skill. Now,")
    |> mes("I developed this by listening")
    |> mes("to incantations by the Utan")
    |> mes("Shaman in Umbala.")
    |> next()
    |> mes("[Riott]")
    |> mes("First, you must stare")
    |> mes("fiercely into the eyes of")
    |> mes("your target, and focus on")
    |> mes("thoughts of dominance. This")
    |> mes("is the basis for mesmerization. Now listen to this incantation...")
    |> next()
    |> mes("[Riott]")
    |> mes("''Toad's leg, Verit's heart,")
    |> mes("spinning stars, spilling zeny,")
    |> mes("hands and feet tied. Is this")
    |> mes("voices yours, is this voice")
    |> mes("mine. Head spinning, head")
    |> mes("spinning, head spinning...!''")
    |> specialeffect2(:talk_frostjoke)
    |> delitem(payment, amount)
    |> skill(@pang_voice, 1, :permanent)
    |> set_char_var(:qskill_bard, 9)
    |> next()
    |> mes("[Riott]")
    |> mes("Remember, it doesn't matter")
    |> mes("what you say, but how you say")
    |> mes("it. Hypnotically induce your")
    |> mes("target with a forbiddenly")
    |> mes("seductive rhythm and your")
    |> mes("grasp will be inescapable!")
    |> next()
    |> mes("[Riott]")
    |> mes("Ah, and use sleight of")
    |> mes("hand to distract your target")
    |> mes("from your true motive! I find")
    |> mes("that casting Unbarring Octave")
    |> mes("with this skill works best. This skill's name is ''Pang Voice!''")
    |> next()
    |> mes("[Riott]")
    |> mes("''Pang Voice'' will mentally")
    |> mes("shock your target and disrupt")
    |> mes("control of his own body for")
    |> mes("a while. You can't exert control")
    |> mes("over victims with this skill, but they usually assume otherwise...")
    |> next()
    |> mes("[Riott]")
    |> mes("You need to be judicious in")
    |> mes("your use of this skill! Don't")
    |> mes("use it recklessly, or people")
    |> mes("will come to hate you as they")
    |> mes("hate me. But ''Pang Voice'' can be welcome is certain situations.")
    |> next()
    |> mes("[Riott]")
    |> mes("Subject your enemies to")
    |> mes("Pang Voice as much as you")
    |> mes("like, and no one will blame")
    |> mes("you for it. And you can get away with casting Pang Voice on bullies")
    |> mes("and drunkards occasionally...")
    |> close()
  end

  defp too_few_eggs(ctx) do
    ctx =
      ctx
      |> mes("[Riott]")
      |> mes("Hmm... You didn't")
      |> mes("bring enough Eggs...")
      |> mes("This will not do. It'll")
      |> mes("be a while until Yhelle")
      |> mes("will be able to lay more")
      |> mes("eggs. Yes, this isn't enough...")
      |> next()
      |> mes("[Riott]")
      |> mes("Well, to make up for the")
      |> mes("missing eggs, go and get ")
      |> mes("me ^4D4DFF1 Munak Doll^000000. I know that")
      |> mes("Yao Jun's Munak Dolls are")
      |> mes("masterpieces, and I am an")
      |> mes("an avid collector of her work.")
      |> next()
      |> mes("[Riott]")

    ctx =
      if count_item(ctx, @egg) > 0 do
        ctx =
          ctx
          |> mes("In the meanwhile,")
          |> mes("I'll enjoy the few")
          |> mes("eggs that you do have!")
          |> mes("Bweh heh heh heh heh!")

        delitem(ctx, @egg, count_item(ctx, @egg))
      else
        ctx
      end

    ctx |> set_char_var(:qskill_bard, 8) |> close()
  end

  defp egg_trouble(ctx) do
    ctx
    |> mes("[Riott]")
    |> mes("So have you been")
    |> mes("having trouble gathering")
    |> mes("eggs from Yhelle? I know")
    |> mes("she can be one fast running")
    |> mes("chicken. But to survive where")
    |> mes("she roosts, she has to be.")
    |> close()
  end

  defp laugh(ctx) do
    ctx
    |> mes("[Riott]")
    |> mes("Hmmrmpf!")
    |> mes("Eh heh heh heh!")
    |> emotion(:kik)
    |> next()
    |> player_says()
    |> mes("Um...")
    |> mes("What's so funny?")
    |> next()
  end

  defp bard_seal(ctx) do
    seal = get_char_var(ctx, :gef_bard_q, 0)
    if seal == 30 or seal == 31, do: seal, else: nil
  end

  defp notice_seal(ctx, seal) do
    ctx =
      ctx
      |> mes("[Riott]")
      |> mes("Hm? Ah! That's one of the")

    ctx =
      if seal == 30 do
        ctx
        |> mes("Black Seals that can only")
        |> mes("be given by Kino Kitty. You")
        |> mes("must be a person of great")
        |> mes("emotional depth if he favors")
        |> mes("you enough to give you that.")
      else
        ctx
        |> mes("Silver Seals that can only")
        |> mes("be given by Errende. You")
        |> mes("must be truly kind at heart")
        |> mes("if he has offered to be your")
        |> mes("friend. How about that?")
      end

    ctx
    |> next()
    |> mes("[Riott]")
    |> mes("Geh heh heh~")
    |> mes("Hey, take a look")
    |> mes("at those two drunks")
    |> mes("all the way over there.")
    |> next()
  end

  defp bard_seal_check(ctx) do
    case bard_seal(ctx) do
      nil ->
        ctx
        |> mes("[Riott]")
        |> mes("Eh, nothing much. Say,")
        |> mes("you don't have any Bard")
        |> mes("Seals? That's a sure sign")
        |> mes("that you haven't been really")
        |> mes("connecting with the Bard")
        |> mes("community. That's a shame...")
        |> next()
        |> mes("[Riott]")
        |> mes("*Sigh* Alright, I know")
        |> mes("how you can meet more Bards.")
        |> mes("Why don't you try making friends with Errende? Look for a Bard")
        |> mes("dressed in green in Geffen and")
        |> mes("you should be able to find him.")
        |> close()

      seal ->
        ctx = ctx |> notice_seal(seal) |> scramble_drunks()

        if get_char_var(ctx, :qskill_bard, 0) == 1,
          do: confess_bungee_jump(ctx),
          else: doubt_power(ctx)
    end
  end

  defp scramble_drunks(ctx) do
    ctx
    |> player_says()
    |> mes("Yeah, I can see them.")
    |> mes("But what's so special")
    |> mes("about those two guys?")
    |> next()
    |> mes("[Riott]")
    |> mes("Just...")
    |> mes("Keep watching.")
    |> next()
    |> mes("^3355FFRiott stared intensely")
    |> mes("at one of the drunken men")
    |> mes("and began to harshly murmur")
    |> mes("some indistinct words in a")
    |> mes("low, hoarse voice. One of the")
    |> mes("men starts slightly convulsing.^000000")
    |> next()
    |> mes("[Little Bit Drunken Guy]")
    |> mes("H-hey...! ^333333*Hiccup!*^000000")
    |> mes("What are you doing?!")
    |> mes("K-keep your hands to")
    |> mes("yourself! Do I look")
    |> mes("like a woman to you?")
    |> next()
    |> mes("[More Drunken Guy]")
    |> mes("What are you talking")
    |> mes("about? Wh-what?! Why")
    |> mes("are my arms all wrapped")
    |> mes("around you? S-sorry, I was")
    |> mes("trying to just go that w--")
    |> mes("I wasn't trying to hug you!")
    |> next()
    |> mes("[Little Bit Drunken Guy]")
    |> mes("Bumping into me,")
    |> mes("I understand. But a full")
    |> mes("blown hug? Come on, now!")
    |> mes("That was totally on purpose!")
    |> mes("Wh-what? My h-hand! It's...")
    |> mes("It's moving my itself?!")
    |> next()
    |> mes("[More Drunken Guy]")
    |> mes("Ack! Wh-what are")
    |> mes("you doing! S-stop")
    |> mes("touching my butt!")
    |> next()
    |> mes("^3355FFThe two men continued")
    |> mes("to gesticulate and move")
    |> mes("wildly without direction.")
    |> next()
    |> player_says()
    |> mes("Those two...")
    |> mes("Those two probably")
    |> mes("had way too much to drink.")
    |> next()
    |> mes("[Riott]")
    |> mes("Nah, they just lost")
    |> mes("control of their bodies")
    |> mes("for a bit. It's the result")
    |> mes("of my skill which sort of")
    |> mes("scrambles their minds.")
    |> next()
  end

  defp confess_bungee_jump(ctx) do
    {ctx, choice} =
      ctx
      |> player_says()
      |> mes("Mind scrambling?")
      |> mes("Wait, are you the same")
      |> mes("Bard who made someone")
      |> mes("jump off Umbala's Bungee")
      |> mes("Jump against his will?")
      |> next()
      |> mes("[Riott]")
      |> mes("Huh? How did you")
      |> mes("learn about that?")
      |> mes("I'm not proud of that,")
      |> mes("(even though it was")
      |> mes("hilarious at the time)")
      |> mes("but yeah, that was me.")
      |> next()
      |> select(["Please teach me that skill!", "Oh, alright. Just checking."])

    if choice == 1, do: request_eggs(ctx), else: respect_traveler(ctx)
  end

  defp request_eggs(ctx) do
    ctx
    |> mes("[Riott]")
    |> mes("Hm? You want to learn")
    |> mes("how to scramble minds")
    |> mes("like I did just now? Well,")
    |> mes("I invented this skill, though")
    |> mes("I did have a lot of help from")
    |> mes("the Utan Shaman. Let's see...")
    |> next()
    |> mes("[Riott]")
    |> mes("Alright. If you want me")
    |> mes("to teach you, then bring me")
    |> mes("5 Eggs from a chicken named")
    |> mes("Yhelle. Yhelle lays the highest")
    |> mes("quality eggs: they're delicious")
    |> mes("and great for a Bard's voice~")
    |> next()
    |> mes("[Riott]")
    |> mes("However, this chicken roosts")
    |> mes("in a strange, dangerous place.")
    |> mes("You'll need to explore this huge, mysterious tree in Umbala in order")
    |> mes("to get there. Last time I went,")
    |> mes("I pretty much almost died.")
    |> next()
    |> mes("[Riott]")
    |> mes("Alright...")
    |> mes("So don't forget")
    |> mes("to come back here")
    |> mes("and bring me back")
    |> mes("^4D4DFF5 Yhelle's Eggs^000000, alright?")
    |> set_char_var(:qskill_bard, 2)
    |> close()
  end

  defp respect_traveler(ctx) do
    ctx
    |> mes("[Riott]")
    |> mes("Boy, you're a curious one.")
    |> mes("But if you know about that")
    |> mes("and you bumped into me, you")
    |> mes("must certainly travel around")
    |> mes("a lot. I can respect a good,")
    |> mes("seasoned adventurer like you.")
    |> close()
  end

  defp doubt_power(ctx) do
    ctx
    |> player_says()
    |> mes("Wha...?")
    |> mes("I can't believe you.")
    |> mes("Mind scrambling? That")
    |> mes("doesn't make any sense!")
    |> mes("They're just really drunk...")
    |> next()
    |> mes("[Riott]")
    |> mes("How dare you question my")
    |> mes("power? Oh well, I suppose")
    |> mes("I really can't be too angry.")
    |> mes("Most people who do believe")
    |> mes("me usually claim that I'm")
    |> mes("an axis of evil about now...")
    |> close()
  end

  defp talk_to_outsider(ctx) do
    ctx = laugh(ctx)

    case bard_seal(ctx) do
      nil ->
        ctx
        |> mes("[Riott]")
        |> mes("Eh, nothing much. Say,")
        |> mes("I notice you don't have")
        |> mes("any Bard seals. That tells")
        |> mes("me that you don't really")
        |> mes("meet that many Bards. You")
        |> mes("should really change that.")
        |> next()
        |> mes("[Riott]")
        |> mes("Bards and Minstrels can")
        |> mes("make some pretty handy")
        |> mes("friends if you give them")
        |> mes("a chance. Here, why don't")
        |> mes("you find Errende in Geffen?")
        |> mes("He's a pretty popular guy...")
        |> close()

      seal ->
        ctx
        |> notice_seal(seal)
        |> player_says()
        |> mes("Yeah, I can see")
        |> mes("together. But what")
        |> mes("about them?")
        |> next()
        |> mes("[Riott]")
        |> mes("Just...")
        |> mes("Keep watching.")
        |> close()
    end
  end
end
