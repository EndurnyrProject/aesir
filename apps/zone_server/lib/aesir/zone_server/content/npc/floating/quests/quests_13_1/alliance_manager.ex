defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests131.AllianceManager do
  @moduledoc """
  The alliance manager who receives the player's report on the three kingdoms' expedition
  into the dimensional rift.

  ## Behavior

  - After the report (step 13) lectures the player on keeping the rift's relics away from
    the other kingdoms.
  - While the report is pending (step 12) hears it out, advances quest 10068 to 10069 and
    sets `ep13_ryu` to 13.
  - Asks everyone else what their business is.

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
        map: "prt_cas",
        x: 19,
        y: 98,
        dir: 7,
        sprite: 752,
        name: "Alliance Manager",
        scope: :renewal,
        unique_name: "Alliance Manager#prt"
      },
      %{
        map: "prt_castle",
        x: 121,
        y: 51,
        dir: 3,
        sprite: 752,
        name: "Alliance Manager",
        scope: :pre_renewal,
        unique_name: "Alliance Manager#prt"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_ryu, 0) do
      13 -> initiatives_lost(ctx)
      12 -> receive_report(ctx)
      _step -> ask_business(ctx)
    end
  end

  defp initiatives_lost(ctx) do
    ctx
    |> mes("[Alliance Manager]")
    |> mes(
      "If we'd had the initiative over Schwarzwald, we could take advantage over them! But we lost the opportunity."
    )
    |> next()
    |> mes("[Alliance Manager]")
    |> mes("Though we are allied with them, that's nothing more than a formality.")
    |> mes("We will take advantage over them.")
    |> next()
    |> mes("[Alliance Manager]")
    |> mes(
      "Do you know what we are here for? These are the things that help to have control over multiple countries and get to know their magic."
    )
    |> next()
    |> mes("[Alliance Manager]")
    |> mes(
      "Whatever. Though the things are not useful to us, we'd better destroy them, to prevent them from being used by others."
    )
    |> next()
    |> mes("[Alliance Manager]")
    |> mes(
      "Anything except things which are not found on Rune-Midgarts... keep them hidden. Just let us know of whatever you are holding."
    )
    |> close()
  end

  defp receive_report(ctx) do
    ctx
    |> mes("[Alliance Manager]")
    |> mes("...Do you have any business with me?")
    |> next()
    |> mes("[Alliance Manager]")
    |> mes("Hm... The boss had you come to me,")
    |> mes("to talk about the issues? Ok!")
    |> next()
    |> mes("[Alliance Manager]")
    |> mes("So, everything is going well?")
    |> mes("You're allied with Schwarzwald?")
    |> mes("They will join with you.")
    |> mes("I know this.")
    |> next()
    |> mes("[Alliance Manager]")
    |> mes("Hm....ok.")
    |> next()
    |> mes("[Alliance Manager]")
    |> mes("You are all going, forward through")
    |> mes("the dimensional rift...")
    |> next()
    |> mes("[Alliance Manager]")
    |> mes("Good. It's started.")
    |> mes("We also need to be preparted to not")
    |> mes("let ourselves be convinced to turn over.")
    |> next()
    |> mes("[Alliance Manager]")
    |> mes("We are so-called 'allies',")
    |> mes("so we can't take advantages over")
    |> mes("each other in public, but we can do")
    |> mes("it secretly.")
    |> next()
    |> mes("[Alliance Manager]")
    |> mes("The Schwarzwald... they are all")
    |> mes("snobs. I know what they did.")
    |> mes("They'll try to get what they can")
    |> mes("with little or no work. I know")
    |> mes("their dirty tricks.")
    |> next()
    |> mes("[Alliance Manager]")
    |> mes("We shouldn't loose anything to them,")
    |> mes("no way! We are not as powerful as")
    |> mes("most of them.")
    |> next()
    |> mes("[Alliance Manager]")
    |> mes("We only have a strange dimensional")
    |> mes("rift in our reserves, but nothing")
    |> mes("else... Only we are about to trick")
    |> mes("them, to win over them!")
    |> next()
    |> mes("[Alliance Manager]")
    |> mes("You are a member of our alliance.")
    |> mes("Always be careful not to get lost.")
    |> next()
    |> changequest(10068, 10069)
    |> set_char_var(:ep13_ryu, 13)
    |> mes("[Alliance Manager]")
    |> mes("Thanks for reporting to us.")
    |> mes("We are better prepared.")
    |> mes("Good job. You can go now.")
    |> close()
  end

  defp ask_business(ctx) do
    ctx
    |> mes("[Alliance Manager]")
    |> mes("Do you have any business here?")
    |> close()
  end
end
