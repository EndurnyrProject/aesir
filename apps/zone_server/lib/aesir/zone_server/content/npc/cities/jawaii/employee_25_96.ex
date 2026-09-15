defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Employee2596 do
  @moduledoc """
  Welcomes married and unmarried patrons to the Jawaii Tavern as Employee Fey.

  ## Behavior

  - Responds to welcome and solo events with different emotions.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii_in",
        x: 25,
        y: 96,
        dir: 0,
        sprite: 724,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#jaw2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnWelcome", ctx), do: emotion(ctx, :chup)
  def on_event("OnSolo", ctx), do: emotion(ctx, :huk)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = ctx |> mes("[Employee Fey]") |> mes("Welcome to Jawaii Tavern~")

    partner_id = getpartnerid(ctx)

    cond do
      Rathena.truthy?(partner_id) -> married_dialogue(ctx)
      not Rathena.truthy?(partner_id) -> single_dialogue(ctx)
      true -> ctx |> mes("I hope you will have a good time~") |> close()
    end
  end

  defp married_dialogue(ctx) do
    ctx
    |> next()
    |> mes("[Employee Fey]")
    |> mes(
      "We hope that you enjoy your time here with the one that you love. Isn't this place nice and cozy,"
    )
    |> mes("a perfect romantic atmosphere?")
    |> next()
    |> mes("[Employee Fey]")
    |> mes(
      "It would be absolutely perfect if it weren't for those 'Invincible Single Army' weirdos. Somehow,"
    )
    |> mes("a few of those dorks found their way here. To hell with them!")
    |> close()
  end

  defp single_dialogue(ctx) do
    ctx
    |> mes("Have a good time! But please,")
    |> mes("try not to interrupt the happily married people here!")
    |> close()
  end
end
