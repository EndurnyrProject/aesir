defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Soldier do
  @moduledoc """
  A grieving soldier shares his story and sends a message to Svetlana.

  ## Behavior

  - Advances the Lusalka quest through conversations with Igor.

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
        map: "moc_pryd04",
        x: 126,
        y: 120,
        dir: 0,
        sprite: 967,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#rus26"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :rhea_rus_main, 0) < 8 ->
        silent_soldier(ctx)

      get_char_var(ctx, :rhea_rus_main, 0) == 8 ->
        quest_conversation(ctx)

      true ->
        lost_earrings(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp quest_conversation(ctx) do
    cond do
      get_char_var(ctx, :rhea_rus_hair, 0) < 5 ->
        silent_soldier(ctx)

      get_char_var(ctx, :rhea_rus_hair, 0) == 4 or
          get_char_var(ctx, :rhea_rus_hair, 0) == 5 ->
        ctx = set_local(ctx, :"player_name$", char_name(ctx, 0))

        if disguised?(ctx) do
          deliver_earrings(ctx)
        else
          missing_disguise(ctx, get_local(ctx, :"player_name$", ""))
        end

      get_char_var(ctx, :rhea_rus_hair, 0) == 6 ->
        if disguised?(ctx), do: hear_message(ctx), else: missing_disguise(ctx, char_name(ctx, 0))

      get_char_var(ctx, :rhea_rus_hair, 0) == 7 ->
        repeat_message(ctx)

      true ->
        lost_earrings(ctx)
    end
  end

  defp disguised?(ctx), do: getequipid(ctx, 2) == 2429 or getequipid(ctx, 2) == 2430

  defp missing_disguise(ctx, name) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", name), "]"))
    |> mes("...Hmm, did I forget to wear something...?")
    |> close()
  end

  defp silent_soldier(ctx) do
    ctx
    |> mes("[A gloomy looking soldier]")
    |> mes("............................")
    |> close()
  end

  defp lost_earrings(ctx) do
    ctx
    |> mes("[A gloomy looking soldier]")
    |> mes("... I feel like I lost something precious.")
    |> next()
    |> mes("- He looks down at the golden earrings and rubs it carefully -")
    |> close()
  end

  defp deliver_earrings(ctx) do
    ctx =
      ctx
      |> mes("[A gloomy looking soldier]")
      |> mes("............................")
      |> next()
      |> mes("[A gloomy looking soldier]")
      |> mes("...I don't know who you are. Just get outta my face. I don't want to talk...")
      |> next()

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", get_local(ctx, :"player_name$", "")),
          "]"
        )
      )
      |> mes("It's pretty dangerous here. There are fierce monsters all over the place.")
      |> next()
      |> mes("[A gloomy looking soldier]")
      |> mes("... Good. Let them come. I want to die here alone.")
      |> next()

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", get_local(ctx, :"player_name$", "")),
          "]"
        )
      )
      |> mes("A-Are you Igor? What're you talking about? Have you gone nuts?")
      |> next()

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", get_local(ctx, :"player_name$", "")),
          "]"
        )
      )
      |> mes("Do you have any idea how much your lover is suffering?")
      |> next()
      |> mes("[A gloomy looking soldier]")
      |> mes("My... lover...?")
      |> next()

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", get_local(ctx, :"player_name$", "")),
          "]"
        )
      )
      |> mes(
        "I brought a message from her. She says not to suffer anymore and to just be happy..."
      )
      |> next()

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", get_local(ctx, :"player_name$", "")),
          "]"
        )
      )
      |> mes(
        "The more you suffer, the deeper she sinks into sadness. Don't think that you're the only one that's suffering..."
      )
      |> next()
      |> mes("[A gloomy looking soldier]")
      |> mes("...Svetlana?!")
      |> mes("Wait, how could you...? She... how do I know that she really spoke to you?!")
      |> next()
      |> mes("-^0000ff Without a word, ^000000-")
      |> mes("-^0000ff you give him Lusalka's ^000000-")
      |> mes("-^0000ff golden earrings ^000000-")
      |> next()
      |> mes("[A gloomy looking soldier]")
      |> mes("T, this is Svetlana's...?!")
      |> mes("H, how did you!?")
      |> next()

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", get_local(ctx, :"player_name$", "")),
          "]"
        )
      )
      |> mes("I met her by accident. She became Lusalka in the marsh of Moscovia.")
      |> next()

    ctx
    |> mes(
      Rathena.concat(
        Rathena.concat("[", get_local(ctx, :"player_name$", "")),
        "]"
      )
    )
    |> mes(
      "She told me that you wouldn't believe me so she gave me these earrings as proof... The present that you gave to her."
    )
    |> next()
    |> mes("[A gloomy looking soldier]")
    |> mes("Is that true?")
    |> mes("Did she really become Lusalka?")
    |> next()
    |> mes("[A gloomy looking soldier]")
    |> mes(
      "It was near the end of the harsh Moscovia winter... She... didn't realize that the ice on the marsh was already melting..."
    )
    |> next()
    |> mes("[A gloomy looking soldier]")
    |> mes(
      "By then, it was too late the ice cracked where she was and she fell into the freezing cold marsh."
    )
    |> next()
    |> mes("[A gloomy looking soldier]")
    |> mes("She wasn't able to swim. I tried to get her out but it was impossible.")
    |> next()
    |> mes("[A gloomy looking soldier]")
    |> mes(
      "She sunk quickly into the marsh. I was able to reach her hand but, she realized that it would kill both of us and she released my hand... I regret that moment every single day."
    )
    |> next()
    |> mes("[A gloomy looking soldier]")
    |> mes(
      "My last memory of her was of her smiling, as she sunk into the cold, wet marsh. As if to say, 'You will be ok.'"
    )
    |> next()
    |> mes("[A gloomy looking soldier]")
    |> mes(
      "I, I was a coward. I was too afraid of drowning to pull her out of the marsh. Too afraid of...."
    )
    |> mes("Oh... Svetlana!!!")
    |> set_char_var(:rhea_rus_hair, 6)
    |> close()
  end

  defp hear_message(ctx) do
    ctx =
      ctx
      |> mes("[A gloomy looking soldier]")
      |> mes(
        "I knew that she had become the cursed nymph Lusalka. But, I still went every night... to find her. I just wanted to see her and talk to her."
      )
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(
        "She told me that she also wanted to see you. But, she was afraid that Lusalka's curse would kill you if you saw her."
      )
      |> mes("And so she hid...")
      |> next()
      |> mes("[A gloomy looking soldier]")
      |> mes("How could she think of me...")
      |> mes("...I, how should I.. Should I...")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Don't be sad. She still loves you. Your suffering is her suffering.")
    |> next()
    |> mes("[A gloomy looking soldier]")
    |> mes(
      "................................................She is? Thank you. You've encouraged me."
    )
    |> next()
    |> mes("[A gloomy looking soldier]")
    |> mes("I will go back to Moscovia. But, I'm not well enough at the moment to go back.")
    |> next()
    |> mes("[A gloomy looking soldier]")
    |> mes("Could you please go to her and tell her my message?")
    |> mes("I remember every moment I've had with her and... I still love her.")
    |> next()
    |> mes("[A gloomy looking soldier]")
    |> mes(
      "Before the full moon, I will be back to Moscovia and meet her. I will come back so strong and happy that when I go to see her she will not suffer anymore."
    )
    |> set_char_var(:rhea_rus_hair, 7)
    |> close()
  end

  defp repeat_message(ctx) do
    ctx
    |> mes("[A gloomy looking soldier]")
    |> mes("Could you please go to her and tell her my message?")
    |> mes("I remember every moment I've had with her and... I still love her.")
    |> next()
    |> mes("[A gloomy looking soldier]")
    |> mes(
      "Before the full moon, I will be back to Moscovia and meet her. I will come back so strong and happy that when I go to see her she will not suffer anymore."
    )
    |> close()
  end
end
