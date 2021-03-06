return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Resources = require(ReplicatedStorage:WaitForChild("Resources"))

	local Auras = require(script.Parent.Parent.Aurora).Auras
	local Effects = require(script.Parent.Parent.Aurora).Effects
	local AuraAgent = require(script.Parent)

	describe("AuraAgent:Apply", function()
		it("Should apply auras", function()
			local agent = AuraAgent.new(workspace, Auras, Effects)

			local success = agent:Apply("TestAuraStandard")

			expect(success).to.equal(true)
			expect(agent:Has("TestAuraStandard")).to.equal(true)
			expect(agent:Get("TestAuraStandard")).to.be.a("table")
			expect(agent:Get("TestAuraStandard").Status.Duration).to.equal(10)
			expect(agent:Get("TestAuraStandard").ReplicatedSections.Status).to.equal(true)
			expect(agent:Get("TestAuraStandard").ReplicatedSections.Display).to.never.be.ok()
			expect(agent:Get("TestAuraStandard").ReplicatedSections.Params).to.never.be.ok()
		end)

		it("Should merge aura info with given props", function()
			local agent = AuraAgent.new(workspace, Auras, Effects)

			agent:Apply("TestAuraStandard", {
				Display = {
					Title = "Test Title";
					Description = function(self)
						return self.Display.Title .. "!"
					end
				};
				Status = {
					Duration = math.huge;
					Visible = false;
				};
				Params = {
					Speed = 11;
				}
			})

			local aura = agent:Get("TestAuraStandard")

			expect(aura.Display.Title).to.equal("Test Title")
			expect(aura.Display.Description).to.equal("Test Title!")
			expect(aura.Status.Duration).to.equal(math.huge)
			expect(aura.Status.Visible).to.equal(false)
			expect(aura.Params.Speed).to.equal(11)
			expect(aura.Params.Test).to.equal(59)
			expect(aura.ReplicatedSections.Status).to.equal(true)
			expect(aura.ReplicatedSections.Display).to.equal(true)
			expect(aura.ReplicatedSections.Status).to.equal(true)
			expect(aura.ReplicatedSections.Params).to.equal(true)
		end)

		it("Should fire the AuraAdded event and hook", function()
			local agent = AuraAgent.new(workspace, Auras, Effects)

			local hookCalled = false
			spawn(function()
				agent:Apply("TestAuraStandard", {
					Hooks = {
						AuraAdded = function()
							hookCalled = true
						end
					}
				})
			end)

			local eventFired = false
			agent.AuraAdded:Connect(function(aura)
				eventFired = true
				expect(aura.Id).to.equal("TestAuraStandard")
			end)

			wait()

			expect(eventFired).to.equal(true)
			expect(hookCalled).to.equal(true)
		end)

		it("Should refresh duration if re-applied", function()
			local agent = AuraAgent.new(workspace, Auras, Effects)
			agent:Apply("TestAuraStandard")
			local aura1 = agent:Get("TestAuraStandard")
			agent:Apply("TestAuraStandard")
			local aura2 = agent:Get("TestAuraStandard")

			expect(aura1).never.to.equal(aura2)
			expect(aura2.Status.Stacks).to.equal(1)
		end)

		it("Should stack stackable auras", function()
			local agent = AuraAgent.new(workspace, Auras, Effects)
			agent:Apply("TestAuraStackable")
			agent:Apply("TestAuraStackable")
			agent:Apply("TestAuraStackable")

			expect(agent:Get("TestAuraStackable").Status.Stacks).to.equal(3)
		end)

		it("Should fire the AuraStackAdded event", function()
			local agent = AuraAgent.new(workspace, Auras, Effects)

			local callCount = 0
			agent.AuraStackAdded:Connect(function(aura)
				callCount = callCount + 1
				expect(aura.Id).to.equal("TestAuraStackable")
				expect(aura.Status.Stacks).to.equal(callCount + 1)
			end)

			agent:Apply("TestAuraStackable")
			agent:Apply("TestAuraStackable")
			agent:Apply("TestAuraStackable")

			wait()
			expect(callCount).to.equal(2)
		end)
	end)

	it("Should fire the AuraRemoved event and hook", function()
		local agent = AuraAgent.new(workspace, Auras, Effects)
		local hookCalled = false
		agent:Apply("TestAuraStandard", {
			Hooks = {
				AuraRemoved = function()
					hookCalled = true
				end
			}
		})

		local eventFired = false
		agent.AuraRemoved:Connect(function(aura)
			eventFired = true
			expect(aura.Id).to.equal("TestAuraStandard")
		end)

		agent:Remove("TestAuraStandard")

		wait()

		expect(eventFired).to.equal(true)
		expect(hookCalled).to.equal(true)
	end)

	describe("AuraAgent:Update", function()
		local testObject = Instance.new("BoolValue", game.TestService)

		it("Should update auras when Update is called", function()
			local agent = AuraAgent.new(testObject, Auras, Effects)

			local success = agent:Apply("TestAuraStandard")

			agent:Update(0.2)

			expect(success).to.equal(true)
			expect(agent:Has("TestAuraStandard")).to.equal(true)
			expect(agent:Get("TestAuraStandard")).to.be.a("table")
			expect(agent:Get("TestAuraStandard").Status.Duration).to.equal(9.8)
			expect(testObject.Name).to.equal("1")
		end)
	end)
end