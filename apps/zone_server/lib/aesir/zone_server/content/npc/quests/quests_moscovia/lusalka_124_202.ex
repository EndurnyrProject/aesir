defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Lusalka124202 do
  @moduledoc """
  Lusalka seeks news of her lover Igor.

  ## Behavior

  - Holy Water protects visitors, and quest progression leads to her request and its aftermath.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_fild02",
        x: 124,
        y: 202,
        dir: 3,
        sprite: 971,
        name: "Lusalka",
        scope: :shared,
        unique_name: "Lusalka#rus23"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnEnable", ctx) do
    ev_onenable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer300000", ctx) do
    ev_ontimer300000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnDisable", ctx) do
    ev_ondisable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if Rathena.truthy?(count_item(ctx, 523)) do
      protected_dialogue(ctx, get_char_var(ctx, :rhea_rus_main, 0))
    else
      ctx
      |> mes("-When Lusalka watches you, you are blacked out-")
      |> specialeffect2(:flasher)
      |> percent_heal(hp: -60, sp: 0)
      |> donpcevent("Lusalka#rus23::OnDisable")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp protected_dialogue(ctx, main) do
    cond do
      main < 8 ->
        greeting(ctx)

      main == 8 ->
        quest_dialogue(ctx, get_char_var(ctx, :rhea_rus_hair, 0))

      true ->
        ctx
    end
  end

  defp quest_dialogue(ctx, hair) do
    cond do
      hair < 2 ->
        greeting(ctx)

      hair in [2, 7] and getequipid(ctx, 2) != 2429 and getequipid(ctx, 2) != 2430 ->
        missing_shoes(ctx)

      hair == 2 ->
        request(ctx)

      hair > 2 and hair < 7 ->
        reminder(ctx)

      hair == 7 ->
        return_message(ctx)

      true ->
        ghost(ctx)
    end
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Lusalka]")
    |> mes("...Your alive...")
    |> mes("My stare didn't...")
    |> mes("What are you doing here...?")
    |> close()
  end

  defp missing_shoes(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...Hmm, did I forget to wear something...?")
    |> close()
  end

  defp request(ctx) do
    {ctx, _} =
      ctx
      |> mes("...Your alive...")
      |> mes("My stare didn't...")
      |> mes("What are you doing here...?")
      |> next()
      |> mes("[Lusalka]")
      |> mes("Nighttime for the aqua nymph.")
      |> mes(
        "Haven't you heard that Lusalka's stare can kill people. If you didn't have the 'Holy Water', you would surely have died."
      )
      |> next()
      |> select(["I am an adventurer and..."])

    ctx =
      ctx
      |> mes("[Lusalka]")
      |> mes("...An adventurer...?")
      |> mes("If so, you came here from another continent, not Moscovia...?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I'm from Rune-Midgarts.")
      |> next()
      |> mes("[Lusalka]")
      |> mes("...Rune... Midgarts...")
      |> mes(
        "A few days ago, my lover left for Rune-Midgarts.. Can you find him for me? I want to talk with him..."
      )
      |> next()
      |> mes("[Lusalka]")
      |> mes(
        "...I don't know why but, I can't remember how I became Lusalka. When I woke up, I was lying down on the bottom of the river."
      )
      |> next()
      |> mes("[Lusalka]")
      |> mes(
        "I forgot everything, but not him. His smile and warm hand. I remember everything about him."
      )
      |> next()
      |> mes("[Lusalka]")
      |> mes(
        "I watched him from the bottom of the river sitting randomly around the river and staring into the marsh. With very sad eyes."
      )
      |> next()
      |> mes("[Lusalka]")
      |> mes(
        "I suffered seeing him grieve, but wasn't able to meet him. Ordinary people are killed immediately when they see Lusalka's stare..."
      )
      |> next()
      |> mes("[Lusalka]")
      |> mes(
        "I saw him coming to the marsh everyday and heard him mourning. And his assurance to go to Rune-Midgarts."
      )
      |> next()
      |> mes("[Lusalka]")
      |> mes(
        "Adventurer, can you find him for me? I can't leave this marsh. Please, find him for me?"
      )
      |> next()
      |> mes("[Lusalka]")
      |> mes(
        "I don't want him to come back or to meet me again. But, Please tell him that I hope he'll stop suffering and to be happy."
      )
      |> next()
      |> mes("[Lusalka]")
      |> mes(
        "I became Lusalka, but it is ok. I'm not sad. But, I can feel his sadness around this river that surrounds me. I feel sorry about it."
      )
      |> next()
      |> mes("[Lusalka]")
      |> mes("Please, find him and tell him that I am ok and to stop suffering...")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Where can I find him?")
      |> next()
      |> mes("[Lusalka]")
      |> mes(
        "The night when he left, he said that he would go to the capital of Rune-Midgarts. I am not sure if he is still there..."
      )
      |> next()
      |> select(["Ok, I will do it", "I don't think I can do it..."])

    if choice == 2 do
      decline(ctx)
    else
      accept(ctx)
    end
  end

  defp decline(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Rune-Midgarts is large! I don't think I can do it.")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("There's nothing we can do. Just give it up.")
    |> next()
    |> mes("[Lusalka]")
    |> mes("Ah... but...")
    |> emotion(:cry)
    |> donpcevent("Lusalka#rus23::OnDisable")
    |> close()
  end

  defp accept(ctx) do
    ctx
    |> mes("[Lusalka]")
    |> mes(
      "Ah! Thank you so much! His name is '^0000ffIgor^000000'. Ah, give these earrings to him. He gave them to me as a present."
    )
    |> next()
    |> mes("- ^0000ffI receive the^000000 -")
    |> mes("- ^0000ffgolden earrings^000000 -")
    |> mes("- ^0000fffrom Lusalka!^000000 -")
    |> set_char_var(:rhea_rus_hair, 3)
    |> donpcevent("Lusalka#rus23::OnDisable")
    |> close()
  end

  defp reminder(ctx) do
    ctx
    |> mes("[Lusalka]")
    |> mes(
      "His name is 'Igor'.. He has gone to the capital of Rune-Midgarts. Give him my golden earrings."
    )
    |> next()
    |> mes("[Lusalka]")
    |> mes("And please, tell him to stop suffering and to be happy. This is my request.")
    |> close()
  end

  defp return_message(ctx) do
    ctx =
      ctx
      |> mes("[Lusalka]")
      |> mes("Have you seen him? How was he?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("This is a message from Igor.")
      |> mes("He said that he remembers every moment with you and still loves you.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(
        "And he would come back to Moscovia until the full moon and wanted you to meet him. He told me that he will be strong enough not to make you suffer."
      )
      |> next()
      |> mes("[Lusalka]")
      |> mes("Igor...")
      |> next()
      |> mes("[Lusalka]")
      |> mes("Thank you very much. I really appreciate it.")
      |> mes("How can I thank you? Let me know what I can do for you.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Can I ask a favor of you?")
      |> next()
      |> mes("[Lusalka]")
      |> mes("If I can, I will do it.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("If so!!")
      |> mes("....I need some of your hair.")
      |> next()
      |> mes("[Lusalka]")
      |> mes("...Eh, hair? Is that all?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Actually it's not all.")
      |> mes("I need 2 lockes!")
      |> next()
      |> mes("[Lusalka]")
      |> mes("Ah, hahaha.")
      |> mes("Is that what you wanted? Huhu, sure take what you want.")
      |> next()
      |> mes("- Lusalka cuts some -")
      |> mes("- of her hair with her -")
      |> mes("- sharp nails -")
      |> next()
      |> mes("[Lusalka]")
      |> mes("Here, my hair...?!")
      |> mes("Aaaaaaaah!??!?!")
      |> sc_start(:sc_curse, 60_000, 0)
      |> specialeffect2(:lord)

    ctx =
      ctx
      |> emotion(:huk, playerattached(ctx))
      |> percent_heal(hp: -30, sp: 0)
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("W, what was that!?")
      |> mes("Who's there?!")
      |> next()
      |> mes("[Voice unidentified]")
      |> mes("Don't think that you've succeeded in keeping me sealed in this prison you fool!")
      |> mes("You will never stop me!!!")
      |> mes("hahahaha!!!")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("W, who are you!? Ahkkk!!")
    |> sc_start(:sc_blind, 10_000, 0)
    |> set_char_var(:rhea_rus_hair, 8)
    |> donpcevent("Lusalka#rus23::OnDisable")
    |> close()
  end

  defp ghost(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...?! What are you? The marsh ghost?")
    |> next()
    |> mes("[Lusalka]")
    |> mes("..........................")
    |> next()
    |> mes(
      "- The green thing seems to open its mouth to say something but closes it soon after and watches you with its sad eyes-"
    )
    |> close()
  end

  def ev_onenable(ctx) do
    ctx |> initnpctimer() |> enablenpc("Lusalka#rus23")
  end

  def ev_ontimer300000(ctx) do
    ev_ondisable(ctx)
  end

  def ev_ondisable(ctx) do
    ctx |> stopnpctimer() |> ev_oninit()
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Lusalka#rus23")
  end
end
