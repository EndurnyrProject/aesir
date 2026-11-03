defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuArcher.BardJet do
  @moduledoc """
  Jet, a former Archer turned Bard, who tells jokes and points Archers to the Icarus guild.

  ## Behavior

  - Archers trade jokes with him (a frost joke for men, a scream for women) and are sent
    to the Icarus Archer guild beside the job change office.
  - Bards hear his newest joke, Dancers get an invitation to perform together, and
    everyone else hears a mafia joke.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche
    - Euphy
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon_in02",
        x: 67,
        y: 65,
        dir: 3,
        sprite: 51,
        name: "Bard Jet",
        scope: :shared,
        unique_name: "Bard Jet#tu"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Jet]")
      |> mes("Every god never grows old")
      |> mes("Because of beautiful")
      |> mes("Goddess, Idun.")
      |> mes("Keeper of the apples of youth")
      |> mes("Goddess of immortality.")
      |> next()
      |> mes("[Jet]")

    base_job = Rathena.job_id(base_job(ctx))

    ctx =
      cond do
        base_job == Rathena.job_id(:archer) -> archer_jokes(ctx)
        base_job == Rathena.job_id(:bard) -> bard_joke(ctx)
        base_job == Rathena.job_id(:dancer) -> dancer_greeting(ctx)
        true -> mafia_joke(ctx)
      end

    close(ctx)
  end

  defp archer_jokes(ctx) do
    ctx =
      ctx
      |> mes("Ooh, you're an Archer?")
      |> mes("There was a time when I too")
      |> mes(
        "was an Archer. But I've changed jobs, so now I entertain the masses with my songs and humor."
      )
      |> next()
      |> mes("[Jet]")
      |> mes("Speaking of which...")
      |> mes("Let me tell you a joke!")
      |> mes("Trust me, it's hilarious~")
      |> mes("^333333*Ahem*^000000")
      |> emotion(:surprise)
      |> next()
      |> mes("[Jet]")
      |> mes("A termite walks")
      |> mes("into a bar and says,")
      |> mes("'Is the bar tender here?'")
      |> mes("Hahahahaha!")
      |> mes("Bwehehehehe!")
      |> emotion(:throb)
      |> next()
      |> mes("[Jet]")
      |> mes("Hahaha~!")
      |> mes("Goodness,")
      |> mes("I'm funny!")
      |> mes("Now, you try!")
      |> mes("Come on, make")
      |> mes("up a joke~!")
      |> emotion(:kik)
      |> next()

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        {ctx, _} = select(ctx, ["A joke, eh?"])

        ctx
        |> specialeffect2(:talk_frostjoke)
        |> mes("[Jet]")
        |> mes("Oh...")
        |> mes("My...")
        |> mes("God...")
        |> next()
        |> mes("[Jet]")
        |> mes("That was the greatest")
        |> mes("joke I've ever heard in my")
        |> mes("life! You really have a natural")
        |> mes("talent for showmanship! You")
        |> mes("just have to become a Bard!")
      else
        {ctx, _} = select(ctx, ["Scream!"])

        ctx
        |> specialeffect2(:talk_scream)
        |> mes("[Jet]")
        |> mes("W-Wow...")
        |> mes("I don't know why, but that was truly amazing. You must have")
        |> mes("what it takes to become a Dancer...")
      end

    ctx
    |> emotion(:best)
    |> next()
    |> mes("[Jet]")
    |> mes("But before any of that, you've got to get rid of the Archer look, no?")
    |> next()
    |> mes("[Jet]")
    |> mes("Actually I'm a member of")
    |> mes(
      "the ^3131FFArcher's Guild^000000 'Icarus' which is to the ^3131FFleft of the job change office^000000. You should be able to"
    )
    |> mes("learn a lot from there.")
    |> next()
    |> mes("[Jet]")
    |> mes("Now now, go learn")
    |> mes("everything and change")
    |> mes("jobs so that you can")
    |> mes("come play with me!")
  end

  defp bard_joke(ctx) do
    ctx
    |> mes("Ooh...!")
    |> mes("You're...!")
    |> next()
    |> specialeffect2(:talk_frostjoke)
    |> emotion(:best)
    |> mes("[Jet]")
    |> mes("Let's see...")
    |> mes("I've been working")
    |> mes("on a new joke here,")
    |> mes("but I could use some")
    |> mes("feedback. You ready?")
    |> next()
    |> mes("[Jet]")
    |> mes("What did the male")
    |> mes("Merchant say to the")
    |> mes("dancing Isis? Give up?")
    |> next()
    |> mes("[Jet]")
    |> mes("'Mammonite!'")
    |> mes("Get it? 'Cuz he")
    |> mes("throws money at her")
    |> mes("and the word Mammonite")
    |> mes("sounds-- wait. It's not funny")
    |> mes("if I have to explain it, huh?")
  end

  defp dancer_greeting(ctx) do
    ctx
    |> mes("Ooh...!")
    |> mes("Hello, hello!")
    |> mes("Wouldn't it be")
    |> mes("nice if we could")
    |> mes("perform together")
    |> mes("one of these days?")
  end

  defp mafia_joke(ctx) do
    ctx
    |> mes("You look bored...")
    |> mes("Is life really that")
    |> mes("mundane and tiresome?")
    |> mes("Then... I shall make")
    |> mes("you laugh...")
    |> next()
    |> mes("[Jet]")
    |> mes("^333333*Ahem*^000000")
    |> mes("These are the")
    |> mes("famous last words")
    |> mes("of a mafia hit man...")
    |> next()
    |> mes("[Jet]")
    |> mes("'Who put the")
    |> mes("violin in this")
    |> mes("violin case?!'")
    |> mes("Bwahahahahahahah!")
    |> mes("Get the joke?")
  end
end
