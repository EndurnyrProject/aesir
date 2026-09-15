defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Employee3096 do
  @moduledoc """
  Welcomes married and unmarried patrons to the Jawaii Tavern as Employee Kay.

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
        x: 30,
        y: 96,
        dir: 4,
        sprite: 724,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#jaw6"
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
    ctx = ctx |> mes("[Employee Kay]") |> mes("Welcome to Jawaii Tavern~")

    partner_id = getpartnerid(ctx)

    cond do
      Rathena.truthy?(partner_id) -> married_dialogue(ctx)
      not Rathena.truthy?(partner_id) -> single_dialogue(ctx)
      true -> ctx |> mes("I hope you will have a good time.") |> close()
    end
  end

  defp married_dialogue(ctx) do
    ctx
    |> next()
    |> mes("[Employee Kay]")
    |> mes("Oh gosh...!")
    |> mes(
      "Lately, I've been dealing with too many drunks in this place! It's been really hard for me to take care of it all..."
    )
    |> close()
  end

  defp single_dialogue(ctx) do
    ctx
    |> mes(
      "I understand that you want to relax and take a break, but please be careful and don't drink too much."
    )
    |> close()
  end
end
