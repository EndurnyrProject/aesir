defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Priest.DarkLord do
  @moduledoc """
  Demon that tries to frighten Acolytes out of the Priest spiritual training.

  ## Behavior

  - Threatens Priests who pass through.
  - Twice demands that Acolytes turn back; yielding to either threat warps them out of the
    training.
  - Standing firm both times lets the Acolyte continue.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - KarLaeda
    - L0ne_W0lf
    - Samuray22
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_prist",
        x: 168,
        y: 115,
        dir: 4,
        sprite: 1272,
        name: "Dark Lord",
        scope: :shared,
        unique_name: "Dark Lord#prst",
        trigger: {8, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest) -> threaten_priest(ctx)
      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:acolyte) -> threaten_acolyte(ctx)
      true -> ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp threaten_priest(ctx) do
    ctx
    |> mes("[Dark Lord]")
    |> mes(
      "^330033All is doom, darkness and despair! Those who love you will betray you, and all that will be left is grieving and fury!^000000"
    )
    |> next()
    |> mes("[Dark Lord]")
    |> mes("^330033To choose to become a servant of God is to choose eternal pain!")
    |> mes("I shall personally see to that, mortal.^000000")
    |> close()
  end

  defp threaten_acolyte(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Dark Lord]")
      |> mes("^330033Halt, human.")
      |> mes("Who has granted")
      |> mes("you passage?^000000")
      |> next()
      |> mes("[Dark Lord]")
      |> mes(
        "^330033You still wish to become a Priest?! Fool! Then, I shall not let you pass. Go back. Otherwise, you will not survive.^000000"
      )
      |> next()
      |> mes("[Dark Lord]")
      |> mes(
        "^330033It would be so easy for me to snap your fragile body in twain and grind your bones to dust."
      )
      |> mes("Now, go back mortal!^000000")
      |> next()
      |> select(["I'm so sorry. Spare me!", "God will protect me."])

    if choice == 1, do: banish(ctx), else: display_power(ctx)
  end

  defp display_power(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Dark Lord]")
      |> mes(
        "^330033It is no use to feign strength and courage. You are completely helpless before me. Your skills are laughable, and your weapons are but mere toys compared to my power.^000000"
      )
      |> next()
      |> mes("[Dark Lord]")
      |> mes(
        "^330033With just a wave of my hand, you will cease to exist. And no one will remember you. Tremble before the might of my infinite magic!^000000"
      )
      |> next()
      |> select(["I beg you, don't...!", "Begone, vile fiend!"])

    if choice == 1 do
      banish(ctx)
    else
      ctx
      |> mes("[Dark Lord]")
      |> mes("^330033Why...")
      |> mes("Why don't you fear me?!")
      |> mes("For a frail mortal, you")
      |> mes("are quite annoying.^000000")
      |> next()
      |> mes("[Dark Lord]")
      |> mes(
        "^330033When next we meet, I will shall escort you to a realm of suffering where you shall spend years immersed in excruciating pain."
      )
      |> mes("Mark my words...^000000")
      |> close()
    end
  end

  defp banish(ctx) do
    ctx
    |> mes("[Dark Lord]")
    |> mes("^330033Don't ever come back!^000000")
    |> close()
    |> warp("gl_church", 145, 170)
  end
end
