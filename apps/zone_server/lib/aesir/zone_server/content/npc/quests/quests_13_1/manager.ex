defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Manager do
  @moduledoc """
  The manager of the magic-wavelength detector at the Morocc outpost, who reports whether
  the traced target is still alive.

  ## Behavior

  - On `mao_morocc2` step 30 explains that the traced magic stone is intact and therefore its
    target is still alive, sets the step to 31 and advances quest 7035 to 7036.
  - On step 31 asks the player to report that to Captain Echinacea.
  - Otherwise explains the mana detector. The reference repeats the greeting page inside both
    step branches, and so does this module.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 191,
        y: 206,
        dir: 3,
        sprite: 852,
        name: "Manager",
        scope: :shared,
        unique_name: "Manager#moc2_finder"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Manager]")
      |> mes("Everything's okay so far!")
      |> mes("How may I help you?")
      |> next()
      |> mes("[Manager]")

    case get_char_var(ctx, :mao_morocc2, 0) do
      30 -> trace_report(ctx)
      31 -> report_to_echinacea(ctx)
      _step -> device_explanation(ctx)
    end
  end

  defp trace_report(ctx) do
    {ctx, _} =
      ctx
      |> mes("Everything's okay so far!")
      |> mes("How may I help you?")
      |> next()
      |> mes("[Manager]")
      |> mes("Did Captain Echinacea send you?")
      |> mes("I have something to report to you.")
      |> next()
      |> mes("[Manager]")
      |> mes(
        "The magic wavelength of the requested pattern number has not been detected in this area."
      )
      |> mes("It's not possible to trace the number around this area, but..")
      |> next()
      |> select(["But?"])

    ctx
    |> mes("[Manager]")
    |> mes("I can tell this magic pattern is supposed to be used to trace a human being.")
    |> mes("You know tracing magic stones always come in pairs, don't you?")
    |> next()
    |> mes("[Manager]")
    |> mes("Now, magic stones specifically used to trace humans have a special feature.")
    |> next()
    |> mes("[Manager]")
    |> mes("When the target of the trace dies, the pair of stones are automatically destroyed.")
    |> mes("Since this patterned magic stone is still intact..")
    |> next()
    |> mes("[Manager]")
    |> mes(
      "Well, this magic stone serves as proof that the target of the trace is still alive somewhere in the world."
    )
    |> mes("I'll keep watching.")
    |> mes("Hopefully, we'll detect the same wavelength.")
    |> next()
    |> mes("[Manager]")
    |> mes("That's all for today.")
    |> set_char_var(:mao_morocc2, 31)
    |> changequest(7035, 7036)
    |> close()
  end

  defp report_to_echinacea(ctx) do
    ctx
    |> mes("Everything's okay so far!")
    |> mes("How may I help you?")
    |> next()
    |> mes("[Manager]")
    |> mes("Please report this to Captain Echinacea;")
    |> mes("We've failed to trace the location of the target,")
    |> mes("but he's still alive somewhere.")
    |> close()
  end

  defp device_explanation(ctx) do
    ctx
    |> mes(
      "This device detects mana and magic wavelengths around this area. identifying what enemies we're dealing with."
    )
    |> mes("It can be used to trace the wavelengths of location-tracing spells.")
    |> next()
    |> mes("[Manager]")
    |> mes("It's a fantastic product made from a combination of magic and science.")
    |> mes(
      "The Ash Vacuum hasn't been fully explored, and we don't know what kind of dangers to expect in this area."
    )
    |> next()
    |> mes("[Manager]")
    |> mes("By using this device, we can check the change and flow of mana around this area,")
    |> mes("and prepare for any possible threats.")
    |> close()
  end
end
