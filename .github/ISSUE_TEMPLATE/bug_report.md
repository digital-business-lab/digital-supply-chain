---
name: Bug report
about: Something is not working as expected on an island or in the Lab Cloud
labels: bug
---

## Island / Component

<!-- Which island or component is affected? -->
- [ ] Farm Island
- [ ] Factory Island
- [ ] Distributor Island
- [ ] Coffee House Island
- [ ] Lab Cloud
- [ ] Documentation

## Describe the bug

<!-- A clear description of what is not working. -->

## Steps to reproduce

1.
2.
3.

## Expected behaviour

<!-- What should happen? -->

## Actual behaviour

<!-- What actually happens? -->

## Environment

- Island OS: Ubuntu ___
- Docker version: `docker --version`
- Relevant service: <!-- e.g. ChirpStack, ERPNext, Fabric peer -->
- Commit hash: `git rev-parse HEAD`

## Logs

```
paste relevant log output here
journalctl -u farm-deploy.service -n 50
docker compose logs <service> --tail 50
```
