defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.BundleOfFiles do
  @moduledoc """
  Presents Fayruz’s thesis on the history and fall of Juperos.

  ## Behavior

  - Unlocks different chapters and text as the Juperos history quest progresses.
  - Starts the history quest when the player first reads the preface.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in04",
        x: 186,
        y: 125,
        dir: 4,
        sprite: 111,
        name: "Bundle of Files",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^8B6914*Thesis: The Fall of Juperos*")
      |> mes("By Fayruz Khrhiyha")
      |> mes("Sage Castle Researcher^000000")
      |> next()
      |> select(["Table of Contents.", "Leave it alone."])

    case choice do
      1 -> table_of_contents(ctx)
      2 -> leave_file(ctx)
      _ -> ctx
    end
  end

  defp table_of_contents(ctx) do
    if get_char_var(ctx, :yuno_hist, 0) > 4 do
      advanced_contents(ctx)
    else
      initial_contents(ctx)
    end
  end

  defp advanced_contents(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^8B6914 1. Preface")
      |> mes(" 2. Juperos Background")
      |> mes(" 3. Theory Behind Its Fall^000000")
      |> next()
      |> select(["Preface", "Juperos Background", "Theory Behind Its Fall", "Leave it alone."])

    case choice do
      1 -> preface(ctx)
      2 -> background(ctx)
      3 -> theory(ctx)
      4 -> leave_contents(ctx)
      _ -> ctx
    end
  end

  defp preface(ctx) do
    ctx =
      ctx
      |> mes("^8B6914Scholars are certain")
      |> mes("that the Juperos civilization")
      |> mes("used to be located above the")
      |> mes("ground, but it is now buried")
      |> mes("beneath the El Mes Plateau.")
      |> mes("The reasons for the city's")

    if get_char_var(ctx, :yuno_hist, 0) < 9 do
      early_preface(ctx)
    else
      revised_preface(ctx)
    end
  end

  defp early_preface(ctx) do
    ctx =
      ctx
      |> mes("ruin are still nebulous...^000000")
      |> next()
      |> mes("^8B6914There is much speculation")
      |> mes("about the reasons for Jupero's")
      |> mes("downfall, but any documentation")
      |> mes("from that time period has been")
      |> mes("difficult to find. As for now, any evidence we have regarding")
      |> mes("Juperos is inconclusive.^000000")
      |> next()
      |> mes("^8B6914In spite of this lack")
      |> mes("of empirical or concrete")
      |> mes("data on the civilization of")
      |> mes("Juperos, our modern world")
      |> mes("may be able to learn much")
      |> mes("from that ancient city's ruins.")
      |> mes("..................^000000")

    ctx =
      if get_char_var(ctx, :yuno_hist, 0) < 7 do
        ctx = next(ctx)

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Hmmm...")
        |> mes("A whole chapter")
        |> mes("dedicated to saying,")
        |> mes("''We know absolutely")
        |> mes("nothing about something.''")
        |> mes("I should write a book~")
      else
        ctx
      end

    close(ctx)
  end

  defp revised_preface(ctx) do
    ctx
    |> mes("ruin are still in debate...^000000")
    |> next()
    |> mes("^8B6914However, new findings")
    |> mes("regarding the history")
    |> mes("of Juperos have allowed")
    |> mes("us to make a few conclusions.^000000")
    |> close()
  end

  defp background(ctx) do
    cond do
      get_char_var(ctx, :yuno_hist, 0) < 9 -> early_background(ctx)
      get_char_var(ctx, :yuno_hist, 0) == 9 -> interim_background(ctx)
      true -> revised_background(ctx)
    end
  end

  defp early_background(ctx) do
    ctx =
      ctx
      |> mes("^8B6914...")
      |> mes("......")
      |> mes("..........^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("This is all just idle")
    |> mes("conjecture! This paper")
    |> mes("isn't developed enough")
    |> mes("yet to be a real thesis...")
    |> close()
  end

  defp interim_background(ctx) do
    ctx =
      ctx
      |> mes("^8B6914Juperos was built over")
      |> mes("a thousand years ago in")
      |> mes("an era of peace just after")
      |> mes("a major war. Contrary to")
      |> mes("popular belief, there isn't any")
      |> mes("evidence proving that Juno may")
      |> mes("have descended from Juperos.^000000")
      |> next()
      |> mes("^8B6914In fact, there is a")
      |> mes("strong possibility that")
      |> mes("another war, between Juno")
      |> mes("and Juperos, resulted in Juno's")
      |> mes("independence from Juperos and")
      |> mes("the destruction of any existing")
      |> mes("documentation from that era.^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Yes... Of course!")
    |> mes("It all makes sense now!")
    |> close()
  end

  defp revised_background(ctx) do
    ctx
    |> mes("^8B6914Juperos was built over")
    |> mes("a thousand years ago in")
    |> mes("an era of peace just after")
    |> mes("a major war. There is now")
    |> mes("direct evidence linking Juno")
    |> mes("to Juperos proving that Juno")
    |> mes("was but a part of Juperos.^000000")
    |> next()
    |> mes("^8B6914Just like Juno, Juperos")
    |> mes("was a society that prided")
    |> mes("itself on its advancement")
    |> mes("in the sciences which played")
    |> mes("a permeating role in civilized")
    |> mes("life. Science was reponsible for Juperos's rise and downfall.")
    |> close()
  end

  defp theory(ctx) do
    if get_char_var(ctx, :yuno_hist, 0) < 10 do
      early_theory(ctx)
    else
      completed_theory(ctx)
    end
  end

  defp early_theory(ctx) do
    ctx =
      ctx
      |> mes("^8B6914...")
      |> mes("......")
      |> mes("..........^000000")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Huh. This writer keeps")
      |> mes("talking about theories,")
      |> mes("but the more I read, the")
      |> mes("less clear I am on what")
      |> mes("the theory actually is.")
      |> mes("I don't think there is one...")

    ctx |> emotion(:sweat, playerattached(ctx)) |> close()
  end

  defp completed_theory(ctx) do
    ctx
    |> mes("^8B6914What is most unsettling")
    |> mes("is recent evidence, including")
    |> mes("a first hand written account,")
    |> mes("regarding the role of one of")
    |> mes("Jupero's foremost scientists")
    |> mes("in that city's rise and fall.")
    |> next()
    |> mes("^8B6914If these writings are")
    |> mes("authentic, then what actually")
    |> mes("happened was that a scientific")
    |> mes("revolution occurred as a direct")
    |> mes("result of one scientist's effort to manipulate the energies of the")
    |> mes("artifact known as Ymir's heart.")
    |> next()
    |> mes("^8B6914This one man and Ymir's")
    |> mes("Heart are credited with")
    |> mes("the success and prosperity")
    |> mes("of the Jupero's civilization.")
    |> mes("However, there are various accounts prior to Jupero's fall")
    |> mes("detailing his work with chimera...^000000")
    |> next()
    |> mes("^8B6914This scientist, supposedly")
    |> mes("in his passion to benefit his")
    |> mes("people by finding a scientific")
    |> mes("method for immortality by using")
    |> mes("chimera for testing, was driven")
    |> mes("insane. He experimented on")
    |> mes("himself with disatrous results.^000000")
    |> next()
    |> mes("^8B6914There was an error in the")
    |> mes("energy calibration of Ymir's")
    |> mes("Heart and the scientist was")
    |> mes("transformed into the monster")
    |> mes("we now know as Chimera. He")
    |> mes("and his test subjects were set")
    |> mes("loose into the city of Juperos.^000000")
    |> next()
    |> mes("^8B6914These immortal Chimeras")
    |> mes("razed the entire city, killing")
    |> mes("countless people. Apparently,")
    |> mes("a team of scientists were able")
    |> mes("to salvage a fragment of Ymir's")
    |> mes("Heart, and use it to lauch part")
    |> mes("of Juperos into the sky.^000000")
    |> next()
    |> mes("^8B6914That section of Juperos")
    |> mes("eventually developed into")
    |> mes("the city of Juno. Since the")
    |> mes("scientists who launched Juno into the sky all immediately died")
    |> mes("afterwards from an unknown cause, they left no documentation.^000000")
    |> next()
    |> mes("^8B6914The Chimera, and the")
    |> mes("laboratory in which it")
    |> mes("was created, is rumored to")
    |> mes("remain beneath the ruins of")
    |> mes("the once great city of Juperos.^000000")
    |> close()
  end

  defp leave_contents(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Ugh... My head hurts")
    |> mes("too much from reading")
    |> mes("a book for smarty people.")
    |> mes("I know! I'll play videogames!")
    |> close()
  end

  defp initial_contents(ctx) do
    {ctx, choice} = select(ctx, ["Preface", "Close the file."])

    case choice do
      1 -> initial_preface(ctx)
      2 -> close_file(ctx)
      _ -> ctx
    end
  end

  defp initial_preface(ctx) do
    ctx =
      ctx
      |> mes("^8B6914Scholars are certain")
      |> mes("that the Juperos civilization")
      |> mes("used to be located above the")
      |> mes("ground, but it is now buried")
      |> mes("beneath the El Mes Plateau.")
      |> mes("The reasons for the city's")
      |> mes("ruin are still nebulous...^000000")
      |> next()
      |> mes("^8B6914There is much speculation")
      |> mes("about the reasons for Jupero's")
      |> mes("downfall, but any documentation")
      |> mes("from that time period has been")
      |> mes("difficult to find. As for now, any evidence we have regarding")
      |> mes("Juperos is inconclusive.^000000")
      |> next()
      |> mes("^8B6914In spite of this lack")
      |> mes("of empirical or concrete")
      |> mes("data on the civilization of")
      |> mes("Juperos, our modern world")
      |> mes("may be able to learn much")
      |> mes("from that ancient city's ruins.")
      |> mes("..................^000000")

    ctx =
      if not Rathena.truthy?(get_char_var(ctx, :yuno_hist, 0)) do
        set_char_var(ctx, :yuno_hist, 1)
      else
        ctx
      end

    ctx = next(ctx)

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("This...")
    |> mes("This is supposed to")
    |> mes("be a research thesis?")
    |> mes("There's barely any")
    |> mes("research in it...")
    |> close()
  end

  defp close_file(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Hmm...")
    |> mes("This isn't heavy")
    |> mes("enough to be a real")
    |> mes("academic work. It must")
    |> mes("not even be finished yet.")
    |> close()
  end

  defp leave_file(ctx) do
    cond do
      get_char_var(ctx, :yuno_hist, 0) < 5 -> leave_early(ctx)
      get_char_var(ctx, :yuno_hist, 0) < 7 -> leave_after_start(ctx)
      get_char_var(ctx, :yuno_hist, 0) < 9 -> leave_midway(ctx)
      get_char_var(ctx, :yuno_hist, 0) < 10 -> leave_near_end(ctx)
      true -> leave_completed(ctx)
    end
  end

  defp leave_early(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Nah...")
    |> mes("I'm tired of reading.")
    |> mes("Ironically enough.")
    |> close()
  end

  defp leave_after_start(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I don't feel like")
    |> mes("reading this. Not")
    |> mes("enough pictures...")
    |> close()
  end

  defp leave_midway(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("It looks very sophisticated...")
    |> close()
  end

  defp leave_near_end(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I know this book...")
    |> mes("But I don't feel like")
    |> mes("reading it right now.")
    |> close()
  end

  defp leave_completed(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("This thesis is")
    |> mes("looking pretty good~")
    |> mes("Of course, I did have")
    |> mes("a hand in making it...")
    |> close()
  end
end
