defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Blacksmith.BlacksmithGuildsman109170 do
  @moduledoc """
  Tells visitors the Blacksmith Guild has moved to Einbroch and offers a paid teleport to Izlude.

  ## Behavior

  - Explains the airship route from Izlude through Juno to Einbroch.
  - Teleports visitors to Izlude for 600 zeny.

  ## Credits

  - Original from rAthena, authors and Contributors
    - EREMES THE CANIVALIZER
    - yoshiki
    - Komurka
    - kobra_k88
    - Lupus
    - celest
    - Poki#3
    - Vicious
    - Silent
    - L0ne_W0lf
    - Yommy
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen_in",
        x: 109,
        y: 170,
        dir: 3,
        sprite: 726,
        name: "Blacksmith Guildsman",
        scope: :shared,
        unique_name: "Blacksmith Guildsman#gef"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Blacksmith Guildsman]")
      |> mes("Good day, are you here to visit Blacksmith Guild?")
      |> next()
      |> mes("[Blacksmith Guildsman]")
      |> mes(
        "I thank you for coming this far to visit our guild. However, I regret to inform you that Blacksmith Guild has been"
      )
      |> mes("moved to ^3131FF'Einbroch' in the Schwarzwald Republic^000000.")
      |> next()
      |> mes("[Blacksmith Guildsman]")
      |> mes("You can travel to Schwarzwald Republic by using the airship.")
      |> mes("I can provide you a teleport service to Izlude, where you can use the airship.")
      |> mes("Would you like to move to Izlude immediately?")
      |> next()
      |> select(["How to go to Einbroch", "Yes!", "No, thanks."])

    case choice do
      1 -> explain_route(ctx)
      2 -> teleport_to_izlude(ctx)
      3 -> ctx |> mes("[Blacksmith Guildsman]") |> mes("Please take care!") |> close()
      _ -> ctx
    end
  end

  defp explain_route(ctx) do
    ctx
    |> mes("[Blacksmith Guildsman]")
    |> mes("Oops, haven't you used the airship yet?")
    |> next()
    |> mes("[Blacksmith Guildsman]")
    |> mes(
      "Unlike Rune-Midgarts Kingdom, Schwarzwald Republic has 'the airship' instead of teleport services to move between towns."
    )
    |> next()
    |> mes("[Blacksmith Guildsman]")
    |> mes(
      "In ^3131FF'Izlude'^000000, you can use ^3131FF'the international airship'^000000 which travels between ^3131FFIzlude and Juno in Schwarzwald Republic^000000."
    )
    |> next()
    |> mes("[Blacksmith Guildsman]")
    |> mes(
      "Take the airship, and go to Juno. Then from Juno, you need to take ^3131FFthe domestic airship^000000 to go to Einbroch."
    )
    |> mes(
      "Remember, you are ^3131FFnot going outside of the airport^000000 upon transit from the international to the domestic airship."
    )
    |> next()
    |> mes("[Blacksmith Guildsman]")
    |> mes("It might sound complicated, but you will know once you are in the airport.")
    |> mes("When you arrive in Blacksmith Guild, please send my regard to my coworkers!")
    |> close()
  end

  defp teleport_to_izlude(ctx) do
    if zeny(ctx) < 600 do
      ctx
      |> mes("[Blacksmith Guildsman]")
      |> mes("Excuse me, but you do not have enough money.")
      |> close()
    else
      ctx |> pay_zeny(600) |> warp("izlude", 94, 103)
    end
  end
end
