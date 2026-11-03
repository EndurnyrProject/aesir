defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuAcolyte.IllGirl do
  @moduledoc """
  Angelic, a sick girl tormented by a cursed spirit whom the Acolyte must cure during the
  Acolyte training quest.

  ## Behavior

  - On the dog-feeding step, the player discovers the curse and the quest advances.
  - Once Sister Asthe has hinted at the answer, the player picks a spell to cast: only a
    learned Blessing can lift the curse, succeeding with a chance of 10% per skill level and
    rewarding job experience; other spells fail or are unavailable.
  - After she is cured she thanks the player.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Capuche
    - Euphy
    - Daegaladh
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_monk",
        x: 226,
        y: 257,
        dir: 6,
        sprite: 93,
        name: "Ill Girl",
        scope: :shared,
        unique_name: "Ill Girl#tu"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Angelic]")

    if get_char_var(ctx, :tu_acolyte01, 0) > 12 do
      ctx
      |> mes("Thanks for helping me.")
      |> mes("I'm sad my older sister is no longer with me, but I oughta")
      |> mes("cheer up, right? I'll try my best!")
      |> emotion(:smile)
      |> close()
    else
      ctx =
        ctx
        |> mes("Sister, don't go...")
        |> mes("^333333*Sniff* *Cough cough!*^000000")
        |> mes("It h-hurts so... much...!")
        |> mes("Sis...ter...")

      cond do
        get_char_var(ctx, :tu_acolyte01, 0) == 10 ->
          discover_curse(ctx)

        get_char_var(ctx, :tu_acolyte01, 0) == 11 ->
          ctx
          |> next()
          |> mes("[Angelic]")
          |> mes("It hurts...!")
          |> mes("I... I can't...!")
          |> close()

        get_char_var(ctx, :tu_acolyte01, 0) == 12 ->
          attempt_cure(ctx)

        true ->
          close(ctx)
      end
    end
  end

  defp discover_curse(ctx) do
    {ctx, _} =
      ctx
      |> next()
      |> mes("[Angelic]")
      |> mes("^333333*Sniff...*^000000")
      |> mes("Are you from")
      |> mes("the convent?")
      |> next()
      |> mes("[Angelic]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Angelic]")
      |> mes("Save...")
      |> mes("My sister...")
      |> next()
      |> mes("[Angelic]")
      |> mes("^333333*Sniff sniff*")
      |> mes("^333333*Cough cough*")
      |> mes("H-hurts...")
      |> next()
      |> select(["Are you alright?"])

    ctx
    |> mes("[Angelic]")
    |> mes("My sister...")
    |> mes("She was so beautiful...")
    |> mes("She was such a nice girl.")
    |> mes("But then, one day...")
    |> next()
    |> mes("[Angelic]")
    |> mes("This disgusting looking")
    |> mes(
      "person was coated in this icky stuff and attacked her. She was poisoned and her body became"
    )
    |> mes("colder and... ^333333*Sniff*^000000")
    |> next()
    |> mes("[Angelic]")
    |> mes("I was with her and I got sick too. I wasn't poisoned as badly, but")
    |> mes("my whole body feels heavy and I've been having these nightmares...")
    |> next()
    |> mes("[Angelic]")
    |> mes("^333333*Cough cough!*^000000")
    |> mes("Will I join my")
    |> mes("sister like this?")
    |> next()
    |> mes("^3355FFThis girl looks")
    |> mes("really sick. Maybe you")
    |> mes("should take a better look")
    |> mes("and see what's wrong.^000000")
    |> next()
    |> player_header()
    |> mes("Are you alright?")
    |> mes("................")
    |> next()
    |> specialeffect(:curseattack)
    |> soundeffectall("_curse.wav", 0)
    |> emotion(:huk)
    |> player_header()
    |> mes("This is....!")
    |> mes("A cursed spirit")
    |> mes("is tormenting this")
    |> mes("poor young girl!")
    |> next()
    |> player_header()
    |> mes("I'll cure you...")
    |> mes("For sure.")
    |> set_char_var(:tu_acolyte01, 11)
    |> close()
  end

  defp attempt_cure(ctx) do
    {ctx, spell} =
      ctx
      |> next()
      |> mes("^3355FFYou go towards")
      |> mes("the girl, place your hands")
      |> mes("on her back and perform")
      |> mes("a holy spell...^000000")
      |> next()
      |> select([
        "Heal!",
        "Blessing!",
        "Cure!",
        "Recovery!",
        "Signum Crucis!",
        "B.S Sacramenti!"
      ])

    case spell do
      1 ->
        ctx
        |> player_header()
        |> mes("H...")
        |> mes("Heal !!")
        |> specialeffect(:heal)
        |> next()
        |> nothing_happened()
        |> close()

      2 ->
        cast_blessing(ctx)

      3 ->
        ctx =
          if getskilllv(ctx, 35) > 0 do
            ctx
            |> player_header()
            |> mes("C-Cure...!")
            |> specialeffect(:cure)
            |> next()
            |> nothing_happened()
          else
            skill_not_learned(ctx)
          end

        close(ctx)

      4 ->
        ctx
        |> not_an_acolyte_skill()
        |> close()

      5 ->
        ctx =
          if getskilllv(ctx, 32) > 0 do
            ctx
            |> player_header()
            |> mes("S-Signum...")
            |> mes("Signum Crucis!")
            |> specialeffect(:signum)
            |> next()
            |> nothing_happened()
          else
            skill_not_learned(ctx)
          end

        close(ctx)

      6 ->
        ctx
        |> not_an_acolyte_skill()
        |> close()

      _ ->
        curse_lifted(ctx)
    end
  end

  defp cast_blessing(ctx) do
    if getskilllv(ctx, 34) > 0 do
      ctx =
        ctx
        |> player_header()
        |> mes("B...")
        |> mes("Blessing!")
        |> next()

      if :rand.uniform(100) - 1 < getskilllv(ctx, 34) * 10 do
        ctx =
          ctx
          |> specialeffect(:blessing)
          |> player_header()
          |> mes("I...")
          |> mes("I did it!!")
          |> next()
          |> mes("^3355FFWhat a great")
          |> mes("chance for you to")
          |> mes("practice your abilities!")
          |> mes("It seemed that this good")
          |> mes("deed has improved your skills.^000000")
          |> set_char_var(:tu_acolyte01, 13)

        ctx =
          if Rathena.truthy?(checkre(ctx, 3)) do
            getexp(ctx, 0, 500)
          else
            getexp(ctx, 0, 1000)
          end

        ctx
        |> specialeffect2(:cone)
        |> next()
        |> curse_lifted()
      else
        ctx
        |> player_header()
        |> mes("Huh...?")
        |> mes("It's not working...")
        |> mes("Maybe it's because")
        |> mes("I'm still learning?")
        |> close()
      end
    else
      ctx
      |> skill_not_learned()
      |> close()
    end
  end

  defp curse_lifted(ctx) do
    ctx
    |> mes("[Angelic]")
    |> mes("Ah...")
    |> mes("I feel...")
    |> mes("So relaxed.")
    |> mes("So much lighter...")
    |> next()
    |> mes("[Angelic]")
    |> mes("Did you")
    |> mes("do this?")
    |> mes("Is this the")
    |> mes("power of God?")
    |> close()
  end

  defp nothing_happened(ctx) do
    ctx
    |> mes("^3355FFNothing happened.")
    |> mes("It doesn't look like")
    |> mes("that skill will work.^000000")
  end

  defp skill_not_learned(ctx) do
    ctx
    |> mes("^3355FFYou didn't learn")
    |> mes("this skill yet, so you're")
    |> mes("not able to use it for now.^000000")
  end

  defp not_an_acolyte_skill(ctx) do
    ctx
    |> mes("^3355FFThis isn't a skill")
    |> mes("that Acolytes can use...^000000")
  end

  defp player_header(ctx), do: mes(ctx, "[#{char_name(ctx, 0)}]")
end
