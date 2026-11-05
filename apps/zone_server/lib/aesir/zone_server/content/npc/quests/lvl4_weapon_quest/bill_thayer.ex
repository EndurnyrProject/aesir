defmodule Aesir.ZoneServer.Content.Npc.Quests.Lvl4WeaponQuest.BillThayer do
  @moduledoc """
  A retired weaponsmith helps adventurers finish his four deceased sons' research.

  ## Behavior

  - Recalls each son's guiding saying and advances the corresponding quest stage.
  - Chooses one of two ore recipes for each son's research and repeats its requirements.
  - Declines to forge weapons himself and mourns his sons.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Vicious_Pucca
    - Reddozen
    - MasterOfMuppets
    - Silent
    - erKURITA
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldebaran",
        x: 178,
        y: 239,
        dir: 3,
        sprite: 712,
        name: "Bill Thayer",
        scope: :shared,
        unique_name: "Bill Thayer#lv4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :lv4_weapon, 0) do
      stage when stage in [54, 55, 36, 37, 27, 28] ->
        ctx |> materials(stage) |> close()

      53 ->
        research(ctx, "Waltboughst", 54, 55)

      stage when stage in [49, 50] ->
        effort_advice(ctx)

      stage when stage in [45, 46] ->
        ctx |> materials(stage) |> set_char_var(:lv4_weapon, stage) |> close()

      44 ->
        research(ctx, "Hein", 45, 46)

      stage when stage in [40, 41] ->
        payment_advice(ctx)

      35 ->
        research(ctx, "Reyghema", 36, 37)

      stage when stage in [31, 32] ->
        youth_advice(ctx)

      26 ->
        research(ctx, "Kayron", 27, 28)

      stage when stage in [22, 23] ->
        helpless(ctx)

      _ ->
        retired(ctx)
    end
  end

  defp research(ctx, son, first_recipe, second_recipe) do
    ctx =
      ctx
      |> mes("[Bill Thayer]")
      |> mes("What...?")
      |> mes("#{son}'s research?")
      |> next()
      |> mes("[Bill Thayer]")
      |> mes("How do you know him?")
      |> mes("Were you a friend of his while")
      |> mes("he was still alive? This must be")
      |> mes("an act of providence...")
      |> next()

    recipe = if Enum.random(1..2) == 1, do: first_recipe, else: second_recipe

    ctx
    |> materials(recipe)
    |> set_char_var(:lv4_weapon, recipe)
    |> close()
  end

  defp materials(ctx, recipe) do
    ctx
    |> mes("[Bill Thayer]")
    |> mes("Hmm...")
    |> required_ores(recipe)
    |> next()
    |> mes("[Bill Thayer]")
    |> mes("^333333*Sniff*^000000")
    |> mes("All of my sons passed away")
    |> mes(
      "before they could finish their research. I should have been the one to have died. They were still so young..."
    )
  end

  defp required_ores(ctx, 55) do
    ctx
    |> mes(
      "You'll need 30 Pyroxene, Turquoise and Phlogopite. I'm sure those are the materials you need, but I have no idea what the end product is supposed to be..."
    )
  end

  defp required_ores(ctx, 54) do
    ctx
    |> mes("You'll need 30 Citrin, Agate")
    |> mes(
      "and Muscovite. I'm sure those are the materials you need, but I have no idea what the end product is supposed to be..."
    )
  end

  defp required_ores(ctx, 45) do
    ctx
    |> mes("You'll need 30 Turquoise,")
    |> mes(
      "Biotite and Rose Quartz. I'm sure those are the materials you need, but I have no idea what the end product is supposed to be..."
    )
  end

  defp required_ores(ctx, 46) do
    ctx
    |> mes("You'll need 30 Phlogopite,")
    |> mes(
      "Citrine and Pyroxene. I'm sure those are the materials you need, but I have no idea what the end product is supposed to be..."
    )
  end

  defp required_ores(ctx, 37) do
    ctx
    |> mes("You'll need 30 Biotite,")
    |> mes(
      "Agate and Citrin. I'm sure those are the materials you need, but I have no idea what the end product is supposed to be..."
    )
  end

  defp required_ores(ctx, 36) do
    ctx
    |> mes("You'll need 30 Muscovite,")
    |> mes(
      "Peridot and Rose Quartz. I'm sure those are the materials you need, but I have no idea what the end product is supposed to be..."
    )
  end

  defp required_ores(ctx, 27) do
    ctx
    |> mes("You'll need 30 Turquoise,")
    |> mes(
      "Peridot and Agate. I'm sure those are the materials you need, but I have no idea what the end product is supposed to be..."
    )
  end

  defp required_ores(ctx, 28) do
    ctx
    |> mes("You'll need 30 Phlogopite,")
    |> mes(
      "Pyroxene and Rose Quartz. I'm sure those are the materials you need, but I have no idea what the end product is supposed to be..."
    )
  end

  defp effort_advice(ctx) do
    ctx
    |> mes("[Bill Thayer]")
    |> mes(
      "Don't you have anything better to do? Quit bothering me and do your best to reach your own goals."
    )
    |> next()
    |> mes("[Bill Thayer]")
    |> mes("^333333*Sigh...*^000000")
    |> mes("Still, trying your")
    |> mes("best won't always result")
    |> mes("in success though.")
    |> next()
    |> mes("[Bill Thayer]")
    |> mes("^660000But that's no excuse!^000000")
    |> mes("Every successful man in")
    |> mes("history has tried his best!")
    |> next()
    |> mes("[Bill Thayer]")
    |> mes(
      "I hope you remember that. It's something I used to tell my sons when they were alive. Ha ha ha~"
    )
    |> set_char_var(:lv4_weapon, 50)
    |> close()
  end

  defp payment_advice(ctx) do
    ctx
    |> mes("[Bill Thayer]")
    |> mes("No matter how much you're willing to pay me, I'm not going to forge you any weapons.")
    |> next()
    |> mes("[Bill Thayer]")
    |> mes("Even during my weapon making days,")
    |> mes("I never accepted money from any of")
    |> mes("my clients. Do you know why?")
    |> next()
    |> mes("[Bill Thayer]")
    |> mes(
      "I always told my sons: 'Never accept payment to forge a good weapon. ^333333It brings bad luck.^000000' Don't ask me how that works. It just is."
    )
    |> set_char_var(:lv4_weapon, 41)
    |> next()
    |> mes("[Bill Thayer]")
    |> mes(
      "Even if you offer me something more precious than money, I won't do any weapon smithing for you. Although I might have back when my sons were still alive..."
    )
    |> close()
  end

  defp youth_advice(ctx) do
    ctx
    |> mes("[Bill Thayer]")
    |> mes(
      "All of my sons broke my heart by dying too young. I remember that I always used to tell them: 'Enjoy your youth. ^333333Live without regret.^000000'"
    )
    |> set_char_var(:lv4_weapon, 32)
    |> next()
    |> mes("[Bill Thayer]")
    |> mes(
      "But I never suspected that their lives would be cut so short. Please remember to live life in such a way that regret won't haunt you later. That's the best advice I can give to you."
    )
    |> close()
  end

  defp helpless(ctx) do
    ctx
    |> mes("[Bill Thayer]")
    |> mes("Listen, I told you...")
    |> mes("There's nothing I can do.")
    |> mes("^333333I'm utterly helpless here.^000000")
    |> set_char_var(:lv4_weapon, 23)
    |> next()
    |> mes("[Bill Thayer]")
    |> mes(
      "There's no point in asking me to do anything. Ever since my sons passed away, I haven't been able to function. Please leave me alone."
    )
    |> close()
  end

  defp retired(ctx) do
    ctx
    |> mes("[Bill Thayer]")
    |> mes("Leave me alone...")
    |> mes("I'm just a broken old man.")
    |> next()
    |> mes("[Bill Thayer]")
    |> mes(
      "I don't make weapons anymore for anyone. Maybe I was a well known weaponsmith once, but I just can't bring myself to do any work ever since my sons passed away..."
    )
    |> close()
  end
end
